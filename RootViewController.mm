#import "RootViewController.h"
#import <sys/sysctl.h>
#import <sys/utsname.h>
#include <dlfcn.h>
#include <mach/mach.h>

// IOKit declarations (Private API)
typedef mach_port_t io_service_t;
typedef mach_port_t io_object_t;
extern "C" {
    extern const mach_port_t kIOMasterPortDefault;
    io_service_t IOServiceGetMatchingService(mach_port_t, CFDictionaryRef);
    CFMutableDictionaryRef IOServiceMatching(const char *);
    CFTypeRef IORegistryEntryCreateCFProperty(io_service_t, CFStringRef, CFAllocatorRef, uint32_t);
    kern_return_t IOObjectRelease(io_object_t);
}

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface RootViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) NSMutableArray *sectionTitles;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, strong) NSDictionary *analyticsData;
@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 50, self.view.frame.size.width, 40)];
    titleLabel.text = @"Thông tin pin";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [self.view addSubview:titleLabel];
    
    // File Picker Button
    UIButton *fileBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    fileBtn.frame = CGRectMake(self.view.frame.size.width - 90, 50, 80, 40);
    [fileBtn setTitle:@"Chọn file" forState:UIControlStateNormal];
    fileBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [fileBtn addTarget:self action:@selector(openFilePicker) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:fileBtn];
    
    // TableView
    CGFloat topOffset = 95;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, topOffset, self.view.frame.size.width, self.view.frame.size.height - topOffset) style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self.view addSubview:self.tableView];
    
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    [self refreshData];
    
    // Auto refresh mỗi 3 giây
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(refreshData) userInfo:nil repeats:YES];
}

- (void)openFilePicker {
    if (@available(iOS 14.0, *)) {
        UTType *type = [UTType typeWithIdentifier:@"public.data"];
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[type] asCopy:YES];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (url) {
        [self handleSharedFile:url];
    }
}

- (void)handleSharedFile:(NSURL *)url {
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (content) {
        [self parseBatteryData:content];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lỗi" message:@"Không thể đọc file" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)parseBatteryData:(NSString *)text {
    NSInteger cycles = [self extractNumber:text pattern:@"last_value_CycleCount\":(\\d+)"];
    NSInteger design = [self extractNumber:text pattern:@"last_value_NominalChargeCapacity\":(\\d+)"];
    NSInteger current = [self extractNumber:text pattern:@"last_value_AppleRawMaxCapacity\":(\\d+)"];
    
    if (design > 0 && current > 0) {
        NSInteger health = (current * 100) / design;
        if (health > 100) health = 100;
        self.analyticsData = @{
            @"health": @(health),
            @"cycles": @(cycles),
            @"current": @(current),
            @"design": @(design)
        };
    } else {
        self.analyticsData = nil;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lỗi" message:@"Không tìm thấy dữ liệu pin trong file" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    [self refreshData];
}

- (NSInteger)extractNumber:(NSString *)text pattern:(NSString *)pattern {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match && match.numberOfRanges > 1) {
        return [[text substringWithRange:[match rangeAtIndex:1]] integerValue];
    }
    return 0;
}

- (void)dealloc {
    [self.refreshTimer invalidate];
}

#pragma mark - IOKit Battery Data

- (NSDictionary *)getBatteryData {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"));
    if (!service) return data;
    
    // Helper block
    void (^getVal)(NSString *, NSString *) = ^(NSString *ioKey, NSString *dictKey) {
        CFTypeRef ref = IORegistryEntryCreateCFProperty(service, (__bridge CFStringRef)ioKey, kCFAllocatorDefault, 0);
        if (ref) {
            data[dictKey] = (__bridge_transfer id)ref;
        }
    };
    
    getVal(@"CycleCount", @"cycleCount");
    getVal(@"DesignCapacity", @"designCapacity");
    getVal(@"NominalChargeCapacity", @"nominalCapacity");
    getVal(@"CurrentCapacity", @"currentCapacity");
    getVal(@"MaxCapacity", @"maxCapacity");
    getVal(@"Temperature", @"temperature");
    getVal(@"Voltage", @"voltage");
    getVal(@"InstantAmperage", @"amperage");
    getVal(@"IsCharging", @"isCharging");
    getVal(@"ExternalConnected", @"externalConnected");
    getVal(@"AppleRawMaxCapacity", @"rawMaxCapacity");
    getVal(@"AppleRawCurrentCapacity", @"rawCurrentCapacity");
    getVal(@"BatterySerialNumber", @"serial");
    getVal(@"TimeRemaining", @"timeRemaining");
    
    IOObjectRelease(service);
    return data;
}

#pragma mark - Device Info

- (NSString *)deviceModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

- (NSString *)deviceModelName {
    NSString *model = [self deviceModel];
    NSDictionary *names = @{
        @"iPhone13,4": @"iPhone 12 Pro Max",
        @"iPhone14,2": @"iPhone 13 Pro",
        @"iPhone14,3": @"iPhone 13 Pro Max",
        @"iPhone14,4": @"iPhone 13 mini",
        @"iPhone14,5": @"iPhone 13",
        @"iPhone14,7": @"iPhone 14",
        @"iPhone14,8": @"iPhone 14 Plus",
        @"iPhone15,2": @"iPhone 14 Pro",
        @"iPhone15,3": @"iPhone 14 Pro Max",
        @"iPhone15,4": @"iPhone 15",
        @"iPhone15,5": @"iPhone 15 Plus",
        @"iPhone16,1": @"iPhone 15 Pro",
        @"iPhone16,2": @"iPhone 15 Pro Max",
        @"iPhone17,1": @"iPhone 16 Pro",
        @"iPhone17,2": @"iPhone 16 Pro Max",
        @"iPhone17,3": @"iPhone 16",
        @"iPhone17,4": @"iPhone 16 Plus",
    };
    return names[model] ?: model;
}

- (NSString *)uptimeString {
    NSTimeInterval uptime = [[NSProcessInfo processInfo] systemUptime];
    int days = (int)(uptime / 86400);
    int hours = (int)((int)uptime % 86400) / 3600;
    int mins = (int)((int)uptime % 3600) / 60;
    return [NSString stringWithFormat:@"%d ngày %d giờ %d phút", days, hours, mins];
}

- (NSString *)storageString {
    NSError *error;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (attrs) {
        unsigned long long total = [attrs[NSFileSystemSize] unsignedLongLongValue];
        return [NSString stringWithFormat:@"%llu GB", total / 1073741824];
    }
    return @"N/A";
}

#pragma mark - Refresh Data

- (void)refreshData {
    NSDictionary *bat = [self getBatteryData];
    
    self.sectionTitles = [NSMutableArray array];
    self.sections = [NSMutableArray array];
    
    // ===== SECTION 0: Thiết bị =====
    [self.sectionTitles addObject:@""];
    NSString *deviceInfo = [NSString stringWithFormat:@"%@ %@ (iOS %@)", [self deviceModelName], [self storageString], [[UIDevice currentDevice] systemVersion]];
    NSString *uptimeInfo = [NSString stringWithFormat:@"Thời gian hoạt động: %@", [self uptimeString]];
    [self.sections addObject:@[@[@"📱", deviceInfo], @[@"⏱️", uptimeInfo]]];
    
    // ===== SECTION ANALYTICS (TỪ FILE) =====
    if (self.analyticsData) {
        [self.sectionTitles addObject:@"DỮ LIỆU TỪ FILE ANALYTICS"];
        NSMutableArray *analyticsSection = [NSMutableArray array];
        [analyticsSection addObject:@[@"🔋", [NSString stringWithFormat:@"Độ chai pin thực tế: %@%%", self.analyticsData[@"health"]]]];
        [analyticsSection addObject:@[@"🔄", [NSString stringWithFormat:@"Số chu kỳ sạc: %@", self.analyticsData[@"cycles"]]]];
        [analyticsSection addObject:@[@"📈", [NSString stringWithFormat:@"Dung lượng thực tế: %@ mAh", self.analyticsData[@"current"]]]];
        [analyticsSection addObject:@[@"📐", [NSString stringWithFormat:@"Dung lượng thiết kế: %@ mAh", self.analyticsData[@"design"]]]];
        [self.sections addObject:analyticsSection];
    }
    
    // ===== SECTION 1: Thông tin pin =====
    [self.sectionTitles addObject:@"THÔNG TIN PIN"];
    NSMutableArray *pinSection = [NSMutableArray array];
    
    // Dung lượng tối đa (%)
    NSInteger designCap = [bat[@"designCapacity"] integerValue];
    NSInteger nominalCap = [bat[@"nominalCapacity"] integerValue];
    if (designCap > 0 && nominalCap > 0) {
        NSInteger healthPercent = (nominalCap * 100) / designCap;
        [pinSection addObject:@[@"🔋", [NSString stringWithFormat:@"Dung lượng tối đa: %ld%%", (long)healthPercent]]];
    }
    
    // Chu kỳ sạc
    NSInteger cycles = [bat[@"cycleCount"] integerValue];
    [pinSection addObject:@[@"🔄", [NSString stringWithFormat:@"Số chu kỳ sạc: %ld", (long)cycles]]];
    
    // Dung lượng thiết kế
    if (designCap > 0)
        [pinSection addObject:@[@"📐", [NSString stringWithFormat:@"Dung lượng thiết kế: %ld mAh", (long)designCap]]];
    
    // Dung lượng còn lại (max capacity)
    if (nominalCap > 0)
        [pinSection addObject:@[@"📊", [NSString stringWithFormat:@"Dung lượng còn lại: %ld mAh", (long)nominalCap]]];
    
    // Nhiệt độ
    NSInteger tempRaw = [bat[@"temperature"] integerValue];
    if (tempRaw > 0) {
        double tempC = tempRaw / 100.0;
        [pinSection addObject:@[@"🌡️", [NSString stringWithFormat:@"Nhiệt độ hiện tại: %.2f°C", tempC]]];
    }
    
    // Phần trăm pin
    float batteryLevel = [UIDevice currentDevice].batteryLevel;
    if (batteryLevel >= 0)
        [pinSection addObject:@[@"⚡", [NSString stringWithFormat:@"Phần trăm pin hiện tại: %.0f%%", batteryLevel * 100]]];
    
    // Dung lượng hiện tại (mAh)
    NSInteger curCap = [bat[@"currentCapacity"] integerValue];
    if (curCap > 0)
        [pinSection addObject:@[@"📈", [NSString stringWithFormat:@"Dung lượng hiện tại: %ld mAh", (long)curCap]]];
    
    // Điện áp
    NSInteger voltage = [bat[@"voltage"] integerValue];
    if (voltage > 0)
        [pinSection addObject:@[@"⚡", [NSString stringWithFormat:@"Điện áp hiện tại: %.2fV", voltage / 1000.0]]];
    
    // Dòng điện
    NSInteger amperage = [bat[@"amperage"] integerValue];
    if (amperage != 0)
        [pinSection addObject:@[@"🔌", [NSString stringWithFormat:@"Dòng điện hiện tại: %ldmA", (long)amperage]]];
    
    [self.sections addObject:pinSection];
    
    // ===== SECTION 2: Thông tin sạc =====
    [self.sectionTitles addObject:@"THÔNG TIN SẠC"];
    NSMutableArray *chargeSection = [NSMutableArray array];
    
    BOOL isCharging = [bat[@"isCharging"] boolValue];
    BOOL externalConnected = [bat[@"externalConnected"] boolValue];
    NSString *chargeStatus;
    if (isCharging) chargeStatus = @"đang sạc";
    else if (externalConnected) chargeStatus = @"đã kết nối (không sạc)";
    else chargeStatus = @"không sạc";
    [chargeSection addObject:@[@"🔋", [NSString stringWithFormat:@"Trạng thái sạc: %@", chargeStatus]]];
    
    // Serial pin
    NSString *serial = bat[@"serial"];
    if (serial)
        [chargeSection addObject:@[@"🏷️", [NSString stringWithFormat:@"Serial pin: %@", serial]]];
    
    [self.sections addObject:chargeSection];
    
    [self.tableView reloadData];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.textLabel.numberOfLines = 0;
    }
    
    NSArray *row = self.sections[indexPath.section][indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", row[0], row[1]];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

@end
