#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <rootless.h>

#define PREFS_PATH ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.example.resotweak.plist")

static CGFloat gFactor = 1.0;   // 1.0 = native, 0.75 = 75% resolution, etc.

static NSDictionary *loadPrefs(void) {
    return [NSDictionary dictionaryWithContentsOfFile:PREFS_PATH] ?: @{};
}

%group Reso

// Metal games (Unity, Unreal, native Metal engines): scale the drawable.
%hook CAMetalLayer
- (void)setDrawableSize:(CGSize)size {
    %orig(CGSizeMake(MAX(1, floor(size.width * gFactor)),
                     MAX(1, floor(size.height * gFactor))));
}
%end

// OpenGL ES games: scale the view's contentScaleFactor.
%hook UIView
- (void)setContentScaleFactor:(CGFloat)scale {
    Class eagl = NSClassFromString(@"CAEAGLLayer");
    if (eagl && [[self class] layerClass] == eagl) {
        scale = MAX(0.5, scale * gFactor);
    }
    %orig(scale);
}
%end

%end

%ctor {
    @autoreleasepool {
        NSString *bid = NSBundle.mainBundle.bundleIdentifier;
        if (!bid || [bid hasPrefix:@"com.apple."]) return;   // never touch system apps

        NSDictionary *p = loadPrefs();
        if (![p[@"enabled"] boolValue]) return;

        // Per-app opt-in: add bundle IDs to the "apps" array in the prefs plist.
        NSArray *apps = p[@"apps"];
        if (![apps containsObject:bid]) return;

        CGFloat f = [p[@"scale"] doubleValue];
        gFactor = (f >= 0.3 && f <= 1.0) ? f : 1.0;   // clamp: 30%–100%

        %init(Reso);
    }
}
