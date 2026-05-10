#import "RootViewController.h"

@implementation RootViewController {
    UILabel *_healthLabel;
    UILabel *_cycleLabel;
    UILabel *_capacityLabel;
    UILabel *_tempLabel;
    UIButton *_selectFileButton;
}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 80, self.view.frame.size.width, 40)];
    titleLabel.text = @"BATTERY PRO";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:24];
    [self.view addSubview:titleLabel];

    _healthLabel = [self createStatLabelAtY:150 title:@"Độ khỏe pin" value:@"-- %"];
    _cycleLabel = [self createStatLabelAtY:220 title:@"Chu kỳ sạc" value:@"-- lần"];
    _capacityLabel = [self createStatLabelAtY:290 title:@"Dung lượng thực" value:@"-- mAh"];
    _tempLabel = [self createStatLabelAtY:360 title:@"Nhiệt độ" value:@"-- °C"];

    _selectFileButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _selectFileButton.frame = CGRectMake(50, 480, self.view.frame.size.width - 100, 50);
    _selectFileButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.3 alpha:1.0];
    [_selectFileButton setTitle:@"CHỌN FILE ANALYTICS" forState:UIControlStateNormal];
    [_selectFileButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _selectFileButton.layer.cornerRadius = 25;
    _selectFileButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_selectFileButton addTarget:self action:@selector(selectFile) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_selectFileButton];
}

- (UILabel *)createStatLabelAtY:(CGFloat)y title:(NSString *)title value:(NSString *)value {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, self.view.frame.size.width - 40, 60)];
    lbl.numberOfLines = 2;
    lbl.textColor = [UIColor whiteColor];
    lbl.text = [NSString stringWithFormat:@"%@\n%@", title, value];
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.font = [UIFont systemFontOfSize:18];
    [self.view addSubview:lbl];
    return lbl;
}

- (void)selectFile {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeImport];
    picker.delegate = (id<UIDocumentPickerDelegate>)self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self parseBatteryData:content];
}

- (void)parseBatteryData:(NSString *)text {
    // Logic tìm kiếm số từ file log
    NSRegularExpression *cycleRegex = [NSRegularExpression regularExpressionWithPattern:@"last_value_CycleCount\":(\\d+)" options:0 error:nil];
    NSTextCheckingResult *cycleMatch = [cycleRegex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    
    if (cycleMatch) {
        NSString *cycles = [text substringWithRange:[cycleMatch rangeAtIndex:1]];
        _cycleLabel.text = [NSString stringWithFormat:@"Chu kỳ sạc\n%@ lần", cycles];
        // Bạn có thể thêm các logic parse khác tương tự ở đây
    } else {
        _cycleLabel.text = @"Không tìm thấy dữ liệu";
    }
}

@end
