////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMSyncSession_Private.h"

#import "RLMNetworkClient.h"
#import "RLMRefreshResponseModel.h"
#import "RLMSyncManager_Private.h"
#import "RLMSyncUtil.h"
#import "RLMUser_Private.h"
#import "RLMUtil.hpp"

@implementation RLMRealmBindingPackage

- (instancetype)initWithFileURL:(NSURL *)fileURL
                       realmURL:(NSURL *)realmURL
                          block:(RLMErrorReportingBlock)block {
    if (self = [super init]) {
        self.fileURL = fileURL;
        self.realmURL = realmURL;
        self.block = block;
        return self;
    }
    return nil;
}

@end

@interface RLMSyncSession ()

@property (nonatomic, readwrite) RLMUser *parentUser;

@end

@implementation RLMSyncSession

- (instancetype)initWithFileURL:(NSURL *)fileURL {
    if (self = [super init]) {
        self.fileURL = fileURL;
        self.resolvedPath = nil;
        self.deferredBindingPackage = nil;
        self.isBound = NO;
        return self;
    }
    return nil;
}

#pragma mark - per-Realm access token API

- (void)configureWithAccessToken:(RLMServerToken)token expiry:(NSTimeInterval)expiry user:(RLMUser *)user {
    self.parentUser = user;
    self.accessToken = token;
    self.accessTokenExpiry = expiry;
    [self _scheduleRefreshTimer];
}

- (void)_scheduleRefreshTimer {
    static NSTimeInterval const refreshBuffer = 10;

    [self.refreshTimer invalidate];
    NSTimeInterval refreshTime = self.accessTokenExpiry - refreshBuffer;
    NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSince1970:refreshTime]
                                              interval:1
                                                target:self
                                              selector:@selector(refresh)
                                              userInfo:nil
                                               repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    self.refreshTimer = timer;
}

- (void)refresh {
    RLMUser *user = self.parentUser;
    if (!user || !self.resolvedPath) {
        return;
    }
    RLMServerToken refreshToken = user.refreshToken;

    NSDictionary *json = @{
                           kRLMSyncProviderKey: @"realm",
                           kRLMSyncPathKey: self.resolvedPath,
                           kRLMSyncDataKey: refreshToken,
                           kRLMSyncAppIDKey: [RLMSyncManager sharedManager].appID,
                           };

    RLMServerCompletionBlock handler = ^(NSError *error, NSDictionary *json) {
        if (json && !error) {
            RLMRefreshResponseModel *model = [[RLMRefreshResponseModel alloc] initWithJSON:json];
            if (!model) {
                // Malformed JSON
//                [user _reportRefreshFailureForPath:self.path error:nil];
                // TODO: invalidate
                return;
            } else {
                // Success
                NSString *accessToken = model.accessToken;
                self.accessToken = accessToken;
                self.accessTokenExpiry = model.accessTokenExpiry;
                [self _scheduleRefreshTimer];

                realm::Realm::refresh_sync_access_token(std::string([accessToken UTF8String]),
                                                        RLMStringDataWithNSString([self.fileURL path]),
                                                        realm::util::none);
                self.isBound = YES;
            }
        } else {
            // Something else went wrong
//            [user _reportRefreshFailureForPath:self.path error:error];
            // TODO: invalidate
        }
    };
    [RLMNetworkClient postRequestToEndpoint:RLMServerEndpointAuth
                                     server:user.authenticationServer
                                       JSON:json
                                 completion:handler];
}

- (void)setIsBound:(BOOL)isBound {
    _isBound = isBound;
    if (isBound) {
        self.deferredBindingPackage = nil;
    }
}

@end