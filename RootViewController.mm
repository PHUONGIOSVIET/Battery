#import "RootViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation RootViewController {
    UILabel *_healthLabel;
    UILabel *_cycleLabel;
    UILabel *_capacityLabel;
    UILabel *_designLabel;
    UILabel *_tempLabel;
    UIButton *_selectFileButton;
}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor blackColor];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 80, self.view.frame.size.width, 40)];
    titleLabel.text = @"BATTERY PRO";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:28];
    [self.view addSubview:titleLabel];

    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 120, self.view.frame.size.width, 20)];
    subLabel.text = @"Phân tích thông số pin chuyên sâu";
    subLabel.textColor = [UIColor grayColor];
    subLabel.textAlignment = NSTextAlignmentCenter;
    subLabel.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:subLabel];

    _healthLabel = [self createCardAtY:170 title:@"ĐỘ KHỎE PIN" value:@"-- %" color:[UIColor systemGreenColor]];
    _cycleLabel  = [self createCardAtY:260 title:@"CHU KỲ SẠC" value:@"-- lần" color:[UIColor systemBlueColor]];
    _capacityLabel = [self createCardAtY:350 title:@"DUNG LƯỢNG THỰC" value:@"-- mAh" color:[UIColor systemOrangeColor]];
    _designLabel = [self createCardAtY:440 title:@"DUNG LƯỢNG THIẾT KẾ" value:@"-- mAh" color:[UIColor systemPurpleColor]];
    _tempLabel   = [self createCardAtY:530 title:@"NHIỆT ĐỘ" value:@"-- °C" color:[UIColor systemRedColor]];

    _selectFileButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _selectFileButton.frame = CGRectMake(30, 640, self.view.frame.size.width - 60, 55);
    _selectFileButton.backgroundColor = [UIColor systemGreenColor];
    [_selectFileButton setTitle:@"CHỌN FILE ANALYTICS" forState:UIControlStateNormal];
    [_selectFileButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _selectFileButton.layer.cornerRadius = 27;
    _selectFileButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [_selectFileButton addTarget:self action:@selector(selectFile) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_selectFileButton];
}

- (UILabel *)createCardAtY:(CGFloat)y title:(NSString *)title value:(NSString *)value color:(UIColor *)color {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(20, y, self.view.frame.size.width - 40, 75)];
    card.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    card.layer.cornerRadius = 15;
    [self.view addSubview:card];

    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(15, 15, 10, 10)];
    dot.backgroundColor = color;
    dot.layer.cornerRadius = 5;
    [card addSubview:dot];

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(35, 10, 200, 20)];
    titleLbl.text = title;
    titleLbl.textColor = [UIColor grayColor];
    titleLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    [card addSubview:titleLbl];

    UILabel *valueLbl = [[UILabel alloc] initWithFrame:CGRectMake(15, 35, card.frame.size.width - 30, 30)];
    valueLbl.text = value;
    valueLbl.textColor = [UIColor whiteColor];
    valueLbl.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    [card addSubview:valueLbl];

    return valueLbl;
}

- (void)selectFile {
    // Dùng API mới (iOS 14+)
    UTType *type = [UTType typeWithIdentifier:@"public.data"];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[type] asCopy:YES];
    picker.delegate = (id<UIDocumentPickerDelegate>)self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (content) {
        [self parseBatteryData:content];
    } else {
        _healthLabel.text = @"Lỗi đọc file";
    }
}

- (void)parseBatteryData:(NSString *)text {
    NSInteger cycles = [self extractNumber:text pattern:@"last_value_CycleCount\":(\\d+)"];
    NSInteger design = [self extractNumber:text pattern:@"last_value_NominalChargeCapacity\":(\\d+)"];
    NSInteger current = [self extractNumber:text pattern:@"last_value_AppleRawMaxCapacity\":(\\d+)"];
    NSInteger temp = [self extractNumber:text pattern:@"last_value_AverageTemperature\":(\\d+)"];

    if (design > 0 && current > 0) {
        NSInteger health = (current * 100) / design;
        if (health > 100) health = 100;
        _healthLabel.text = [NSString stringWithFormat:@"%ld%%", (long)health];
    }
    _cycleLabel.text = cycles > 0 ? [NSString stringWithFormat:@"%ld lần", (long)cycles] : @"N/A";
    _capacityLabel.text = current > 0 ? [NSString stringWithFormat:@"%ld mAh", (long)current] : @"N/A";
    _designLabel.text = design > 0 ? [NSString stringWithFormat:@"%ld mAh", (long)design] : @"N/A";
    _tempLabel.text = temp > 0 ? [NSString stringWithFormat:@"%ld °C", (long)temp] : @"N/A";
}

- (NSInteger)extractNumber:(NSString *)text pattern:(NSString *)pattern {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match && match.numberOfRanges > 1) {
        return [[text substringWithRange:[match rangeAtIndex:1]] integerValue];
    }
    return 0;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end
