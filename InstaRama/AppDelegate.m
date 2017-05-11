//
//  AppDelegate.m
//  InstaRama
//
//  Created by georgy.kasapidi on 04.05.17.
//  Copyright © 2017 N7. All rights reserved.
//

@import Photos;

#import "AppDelegate.h"

typedef void(^VoidBlock)(void);
typedef void(^DataBlock)(id data);
typedef void(^ResultBlock)(BOOL success);

#define exec_block(block, ...) (block ? block(__VA_ARGS__) : nil)

@interface AppDelegate () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = NO;
    picker.delegate = self;

    self.window = ({
        UIWindow *x = [UIWindow new];
        x.rootViewController = picker;
        [x makeKeyAndVisible];
        x;
    });

    return YES;
}

#pragma mark -

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    NSURL *referenceURL = info[UIImagePickerControllerReferenceURL];

    NSParameterAssert(referenceURL);

    PHAsset *asset = [[PHAsset fetchAssetsWithALAssetURLs:@[referenceURL] options:nil] firstObject];

    if (asset.mediaSubtypes & PHAssetMediaSubtypePhotoPanorama) {
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"instagram://"]]) {
            UIImage *panorama = info[UIImagePickerControllerOriginalImage];

            [self __cropPanorama:panorama];
        } else {
            [self __showAlert:@"Instagram is not installed"];
        }
    } else {
        [self __showAlert:@"Selected photo is not a panorama"];
    }
}

#pragma mark -

- (void)__cropPanorama:(UIImage *)panorama {
    UIActivityIndicatorView *spinner = ({
        UIActivityIndicatorView *x = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        x.color = [UIColor blackColor];
        [self.window addSubview:x];
        x.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
                                                  [x.centerXAnchor constraintEqualToAnchor:self.window.centerXAnchor],
                                                  [x.centerYAnchor constraintEqualToAnchor:self.window.centerYAnchor]
                                                  ]];
        x;
    });

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];

    [spinner startAnimating];

    [self __cropPanorama:panorama
              completion:^(NSArray *ids) {
                  [spinner removeFromSuperview];

                  [[UIApplication sharedApplication] endIgnoringInteractionEvents];

                  [self __openInstaWithAssetID:[ids lastObject]];
              }];
}

- (void)__cropPanorama:(UIImage *)panorama
            completion:(DataBlock)completion {
    const CGFloat n = 4.;

    CGFloat w = panorama.size.height * n / panorama.size.width;

    if (w > 1.) {
        exec_block(completion, nil);

        return;
    }

    CGFloat l = w / n;
    CGFloat p = 1. - (1. - w) / 2. - l;

    NSMutableArray *ids = [NSMutableArray array];

    [self __cropPanorama:panorama
                position:p
                   width:l
                     ids:ids
              completion:^{
                  exec_block(completion, ids);
              }];
}

- (void)__cropPanorama:(UIImage *)panorama
              position:(CGFloat)position
                 width:(CGFloat)width
                   ids:(NSMutableArray *)ids
            completion:(VoidBlock)completion {
    if (position < 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            exec_block(completion);
        });

        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        CGRect cropRegion = CGRectMake(position, 0., width, 1.);

        UIImage *image = [self __cropImage:panorama cropRegion:cropRegion];

        __block NSString *localIdentifier = nil;

        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetChangeRequest *cr = [PHAssetChangeRequest creationRequestForAssetFromImage:image];

            localIdentifier = cr.placeholderForCreatedAsset.localIdentifier;
        } completionHandler:^(BOOL _, NSError *__) {
            NSParameterAssert(localIdentifier);

            [ids addObject:localIdentifier];

            [self __cropPanorama:panorama
                        position:position - width
                           width:width
                             ids:ids
                      completion:completion];
        }];
    });
}

- (void)__openInstaWithAssetID:(NSString *)assetID {
    if (!assetID) {
        return;
    }

    NSString *assetPath = [[NSString stringWithFormat:@"assets-library://asset/asset.JPG?id=%@&ext=JPG", assetID] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];

    NSString *instagramLibrary = [NSString stringWithFormat:@"instagram://library?AssetPath=%@", assetPath];

    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:instagramLibrary]
                                       options:@{}
                             completionHandler:nil];
}

- (void)__showAlert:(NSString *)title {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self.window.rootViewController presentViewController:alert
                                                 animated:YES
                                               completion:nil];
}

- (UIImage *)__cropImage:(UIImage *)image cropRegion:(CGRect)cropRegion {
    CGRect cropRect = CGRectMake(cropRegion.origin.x * image.size.width,
                                 cropRegion.origin.y * image.size.height,
                                 cropRegion.size.width * image.size.width,
                                 cropRegion.size.height * image.size.height);

    CGImageRef imgRef = CGImageCreateWithImageInRect([image CGImage], cropRect);
    UIImage *croppedImage = [UIImage imageWithCGImage:imgRef];
    CGImageRelease(imgRef);

    return croppedImage;
}

@end
