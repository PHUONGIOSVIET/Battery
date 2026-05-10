#import <UIKit/UIKit.h>
#import "RootViewController.h"

@interface BatteryProApplication : UIApplication <UIApplicationDelegate>
@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) RootViewController *viewController;
@end

@implementation BatteryProApplication

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _viewController = [[RootViewController alloc] init];
    _window.rootViewController = _viewController;
    [_window makeKeyAndVisible];
}

@end
