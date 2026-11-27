#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <rootless.h>

#define PREFS_PATH ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.example.resotweak.plist")

static CGFloat gW = 0, gH = 0;   // target resolution in pixels (any order, orientation handled below)
static BOOL gSharp = NO;         // nearest-neighbour upscaling (crisp pixels)

// Target size in the same orientation as `ref` (landscape stays landscape).
static CGSize targetFor(CGSize ref) {
    CGFloat lo = MIN(gW, gH), hi = MAX(gW, gH);
    return (ref.width >= ref.height) ? CGSizeMake(hi, lo) : CGSizeMake(lo, hi);
}

%group Reso

// 1) Metal: force the drawable to the exact X,Y size and make it stretch to fill the layer.
%hook CAMetalLayer
- (void)setDrawableSize:(CGSize)size {
    if (size.width < 1 || size.height < 1) { %orig(size); return; }
    %orig(targetFor(size));                      // idempotent: safe if called repeatedly
    self.contentsGravity = kCAGravityResize;     // stretch to the full screen
    self.magnificationFilter = gSharp ? kCAFilterNearest : kCAFilterLinear;
}
%end

// 2) Make games that read the screen size think the screen IS the target resolution,
//    so their viewport matches the smaller drawable (this is what fixes the cropped/unstretched look).
%hook UIScreen
- (CGRect)nativeBounds {
    CGRect b = %orig;                            // always portrait
    CGSize t = targetFor(b.size);
    return CGRectMake(0, 0, t.width, t.height);
}
- (CGFloat)nativeScale {
    CGSize pts = self.bounds.size;
    if (pts.width < 1) return %orig;
    return targetFor(pts).width / pts.width;
}
%end

// 3) Game views (Metal + OpenGL ES): keep contentScaleFactor consistent and pin the drawable.
%hook UIView
- (void)setContentScaleFactor:(CGFloat)scale {
    Class lc = [[self class] layerClass];
    Class eagl = NSClassFromString(@"CAEAGLLayer");
    BOOL isGL = eagl && [lc isSubclassOfClass:eagl];
    BOOL isMetal = [lc isSubclassOfClass:[CAMetalLayer class]];
    CGSize pts = self.bounds.size;
    if ((isGL || isMetal) && pts.width >= 1 && pts.height >= 1) {
        %orig(targetFor(pts).width / pts.width);
        if (isMetal) ((CAMetalLayer *)self.layer).drawableSize = targetFor(pts);
        return;
    }
    %orig(scale);
}
%end

%end

%ctor {
    @autoreleasepool {
        NSString *bid = NSBundle.mainBundle.bundleIdentifier;
        if (!bid || [bid hasPrefix:@"com.apple."]) return;   // never touch system apps

        NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:PREFS_PATH] ?: @{};
        if (![p[@"enabled"] boolValue]) return;
        // Per-app opt-in: AltList picker, comma-separated text field, or legacy "apps" array.
        BOOL allowed = [p[[@"app-" stringByAppendingString:bid]] boolValue];
        id arr = p[@"apps"];
        if (!allowed && [arr isKindOfClass:[NSArray class]]) allowed = [arr containsObject:bid];
        id csv = p[@"bundleIDs"];
        if (!allowed && [csv isKindOfClass:[NSString class]]) {
            NSCharacterSet *seps = [NSCharacterSet characterSetWithCharactersInString:@", \n;"];
            for (NSString *part in [(NSString *)csv componentsSeparatedByCharactersInSet:seps]) {
                if ([part isEqualToString:bid]) { allowed = YES; break; }
            }
        }
        if (!allowed) return;

        CGFloat w = [p[@"width"] doubleValue], h = [p[@"height"] doubleValue];
        if (w < 240 || h < 240 || w > 8192 || h > 8192) return;    // invalid -> do nothing
        gW = w; gH = h;
        gSharp = [p[@"sharp"] boolValue];

        %init(Reso);
    }
}
