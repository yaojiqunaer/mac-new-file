#import <Cocoa/Cocoa.h>
#import <FinderSync/FinderSync.h>
#import "NewFileConfig.h"
#include <pwd.h>
#include <unistd.h>

@interface LocalNewFileFinder : FIFinderSync
@property(nonatomic, copy) NSURL *targetDirectory;
@property(nonatomic) NSInteger nextCommandTag;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSDictionary *> *commands;
@property(nonatomic, strong) NSMutableArray<NSArray<NSNumber *> *> *menuSnapshots;
@end

@implementation LocalNewFileFinder
- (instancetype)init {
    self = [super init];
    if (self) {
        self.nextCommandTag = 1;
        self.commands = [NSMutableDictionary dictionary];
        self.menuSnapshots = [NSMutableArray array];
        struct passwd *entry = getpwuid(getuid());
        NSString *home = entry ? [NSString stringWithUTF8String:entry->pw_dir] : nil;
        if (home.length) {
            NSURL *homeURL = [NSURL fileURLWithPath:home isDirectory:YES];
            [FIFinderSyncController defaultController].directoryURLs = [NSSet setWithObject:homeURL];
        }
    }
    return self;
}

- (NSMenu *)menuForMenuKind:(FIMenuKind)kind {
    if (kind != FIMenuKindContextualMenuForContainer) return nil;
    NSURL *directory = [[FIFinderSyncController defaultController] targetedURL];
    if (!directory.isFileURL) return nil;
    self.targetDirectory = directory;

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"新建文件"];
    NSMenuItem *root = [[NSMenuItem alloc] initWithTitle:@"新建文件" action:nil keyEquivalent:@""];
    NSMenu *formats = [[NSMenu alloc] initWithTitle:@"新建文件"];
    NSArray *extensions = MFLoadExtensions();
    NSMutableArray<NSNumber *> *snapshotTags = [NSMutableArray array];
    for (NSUInteger i = 0; i < extensions.count; i++) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:MFTitleForExtension(extensions[i]) action:@selector(createFile:) keyEquivalent:@""];
        item.target = self;
        // 仅 tag 穿过 Finder IPC，目录和后缀快照留在扩展进程内。
        NSInteger tag = self.nextCommandTag++;
        item.tag = tag;
        self.commands[@(tag)] = @{@"directory":directory, @"extension":extensions[i]};
        [snapshotTags addObject:@(tag)];
        [formats addItem:item];
    }
    [formats addItem:[NSMenuItem separatorItem]];
    NSMenuItem *settings = [[NSMenuItem alloc] initWithTitle:@"设置文件类型…" action:@selector(openSettings:) keyEquivalent:@""];
    settings.target = self;
    settings.tag = -1;
    [formats addItem:settings];
    [self.menuSnapshots addObject:snapshotTags];
    while (self.menuSnapshots.count > 8) {
        NSArray *expired = self.menuSnapshots.firstObject;
        [self.commands removeObjectsForKeys:expired];
        [self.menuSnapshots removeObjectAtIndex:0];
    }
    root.submenu = formats;
    [menu addItem:root];
    return menu;
}

- (void)createFile:(NSMenuItem *)sender {
    NSDictionary *command = self.commands[@(sender.tag)];
    NSString *extension = command[@"extension"];
    NSURL *directory = command[@"directory"];
    if (!extension || !directory.isFileURL) return;

    NSURLComponents *request = [[NSURLComponents alloc] init];
    request.scheme = @"localnewfile";
    request.host = @"create";
    request.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"directory" value:directory.absoluteString],
        [NSURLQueryItem queryItemWithName:@"extension" value:extension]
    ];
    if (request.URL) [[NSWorkspace sharedWorkspace] openURL:request.URL];
}
- (void)openSettings:(NSMenuItem *)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"localnewfile://settings"]];
}

@end
