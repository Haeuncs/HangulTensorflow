#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Configurations for downloading conditions.
 */
NS_SWIFT_NAME(ModelDownloadConditions)
@interface FIRModelDownloadConditions : NSObject<NSCopying>

/**
 * Indicates whether WiFi is required for downloading. The default is `NO`.
 */
@property(nonatomic, readonly) BOOL isWiFiRequired;

/**
 * Indicates whether the model can be downloaded while the app is in the background. The default is
 * `NO`.
 */
@property(nonatomic, readonly) BOOL canDownloadInBackground;

/**
 * Creates an instance of `ModelDownloadConditions` with the given configuration.
 *
 * @param isWiFiRequired Whether a device has to be connected to WiFi for downloading to start.
 * @param canDownloadInBackground Whether the model can be downloaded while the app is in the
 * background.
 * @return A new instance of `ModelDownloadConditions`.
 */
- (instancetype)initWithIsWiFiRequired:(BOOL)isWiFiRequired
               canDownloadInBackground:(BOOL)canDownloadInBackground NS_DESIGNATED_INITIALIZER;

/**
 * Unavailable.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
