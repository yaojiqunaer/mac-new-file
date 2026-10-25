#import <Cocoa/Cocoa.h>
#import "NewFileConfig.h"
#include <errno.h>
#include <fcntl.h>
#include <pwd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void ShowError(NSString *message) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"无法新建文件";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"好"];
    [NSApp activateIgnoringOtherApps:YES];
    [alert runModal];
}

static BOOL IsWithinHome(NSString *directory, NSString *home) {
    return [directory isEqualToString:home] ||
        [directory hasPrefix:[home stringByAppendingString:@"/"]];
}

static NSURL *CreateEmptyFile(NSString *directoryValue, NSString *extension) {
    NSSet *allowed = [NSSet setWithArray:MFLoadExtensions()];
    NSURL *directoryURL = directoryValue ? [NSURL URLWithString:directoryValue] : nil;
    NSString *path = directoryURL.path;
    unichar zero = 0;
    NSString *nul = [NSString stringWithCharacters:&zero length:1];
    if (![allowed containsObject:extension ?: @""] || !directoryURL.isFileURL ||
        !path.isAbsolutePath || [path rangeOfString:nul].location != NSNotFound ||
        (directoryURL.host.length && ![directoryURL.host isEqualToString:@"localhost"])) {
        ShowError(@"请求参数无效。仅支持本地主目录内的文件夹，以及设置中已保存的文件后缀。");
        return nil;
    }

    struct passwd *user = getpwuid(getuid());
    char *homeBytes = user && user->pw_dir ? realpath(user->pw_dir, NULL) : NULL;
    char *directoryBytes = realpath(path.fileSystemRepresentation, NULL);
    NSString *home = homeBytes ? [[NSFileManager defaultManager]
        stringWithFileSystemRepresentation:homeBytes length:strlen(homeBytes)] : nil;
    NSString *directory = directoryBytes ? [[NSFileManager defaultManager]
        stringWithFileSystemRepresentation:directoryBytes length:strlen(directoryBytes)] : nil;
    free(homeBytes);
    free(directoryBytes);
    if (!home || !directory || !IsWithinHome(directory, home)) {
        ShowError(@"目标必须是当前用户主目录内已存在的文件夹；不支持指向主目录外的符号链接。");
        return nil;
    }

    int directoryFD = open(directory.fileSystemRepresentation,
                           O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (directoryFD < 0) {
        int error = errno;
        ShowError([NSString stringWithFormat:@"无法打开目标文件夹：%@",
            [NSError errorWithDomain:NSPOSIXErrorDomain code:error userInfo:nil].localizedDescription]);
        return nil;
    }
    // 目录句柄固定创建位置，排他创建保证已有文件或符号链接不会被覆盖。
    NSURL *createdURL = nil;
    for (NSUInteger index = 0; ; index++) {
        NSString *name = index == 0 ? [NSString stringWithFormat:@"新建文件.%@", extension] :
            [NSString stringWithFormat:@"新建文件 %lu.%@", (unsigned long)index, extension];
        int fileFD = openat(directoryFD, name.fileSystemRepresentation,
                            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
        if (fileFD >= 0) {
            close(fileFD);
            createdURL = [[NSURL fileURLWithPath:directory isDirectory:YES]
                URLByAppendingPathComponent:name isDirectory:NO];
            break;
        }
        int error = errno;
        if (error != EEXIST || index == NSUIntegerMax) {
            ShowError([NSString stringWithFormat:@"创建空文件失败：%@",
                [NSError errorWithDomain:NSPOSIXErrorDomain code:error userInfo:nil].localizedDescription]);
            break;
        }
    }
    close(directoryFD);
    return createdURL;
}

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic) BOOL receivedURL;
@property(nonatomic, strong) NSWindow *settingsWindow;
@property(nonatomic, strong) NSTextView *extensionsEditor;
@property(nonatomic, strong) NSTextField *statusLabel;
@end

@implementation AppDelegate

// 设置窗口存活期间不自动退出，避免 Finder 创建请求中断尚未保存的编辑。
- (void)terminateIfSettingsClosed:(NSApplication *)application {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (!self.settingsWindow.isVisible) {
            [application terminate:nil];
        }
    });
}

- (void)showSettings {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    if (!self.settingsWindow) {
        NSWindow *window = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(0, 0, 540, 440)
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                      NSWindowStyleMaskMiniaturizable
            backing:NSBackingStoreBuffered defer:NO];
        window.title = @"Mac新建文件";
        window.releasedWhenClosed = NO;
        window.delegate = self;
        [window center];
        self.settingsWindow = window;

        NSTextField *heading = [NSTextField labelWithString:@"Finder 新建文件后缀"];
        heading.font = [NSFont boldSystemFontOfSize:16];
        heading.frame = NSMakeRect(24, 394, 492, 24);
        [window.contentView addSubview:heading];

        NSTextField *instructions = [NSTextField wrappingLabelWithString:
            @"每行填写一个后缀，也可用逗号或空格分隔。保存后，下次打开 Finder 右键菜单时生效。"];
        instructions.frame = NSMakeRect(24, 340, 492, 44);
        [window.contentView addSubview:instructions];

        NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(24, 164, 492, 164)];
        scroll.borderType = NSBezelBorder;
        scroll.hasVerticalScroller = YES;
        NSTextView *editor = [[NSTextView alloc] initWithFrame:scroll.contentView.bounds];
        editor.richText = NO;
        editor.allowsUndo = YES;
        editor.automaticQuoteSubstitutionEnabled = NO;
        editor.automaticDashSubstitutionEnabled = NO;
        editor.automaticTextReplacementEnabled = NO;
        editor.font = [NSFont monospacedSystemFontOfSize:14 weight:NSFontWeightRegular];
        editor.textContainerInset = NSMakeSize(8, 8);
        editor.verticallyResizable = YES;
        editor.horizontallyResizable = NO;
        editor.autoresizingMask = NSViewWidthSizable;
        editor.textContainer.widthTracksTextView = YES;
        editor.string = [MFLoadExtensions() componentsJoinedByString:@"\n"];
        scroll.documentView = editor;
        self.extensionsEditor = editor;
        [window.contentView addSubview:scroll];

        NSTextField *notice = [NSTextField wrappingLabelWithString:
            @"创建的是空文本文件。更改后缀不会生成 Word、Excel、PDF 等格式所需的文档内容。"];
        notice.frame = NSMakeRect(24, 108, 492, 44);
        notice.textColor = [NSColor secondaryLabelColor];
        [window.contentView addSubview:notice];

        NSButton *restore = [NSButton buttonWithTitle:@"恢复默认" target:self action:@selector(restoreDefaults:)];
        restore.frame = NSMakeRect(24, 62, 104, 32);
        [window.contentView addSubview:restore];
        NSButton *save = [NSButton buttonWithTitle:@"保存" target:self action:@selector(saveSettings:)];
        save.frame = NSMakeRect(412, 62, 104, 32);
        save.keyEquivalent = @"\r";
        [window.contentView addSubview:save];

        self.statusLabel = [NSTextField wrappingLabelWithString:@"后缀按填写顺序显示在 Finder 菜单中。"];
        self.statusLabel.frame = NSMakeRect(24, 14, 492, 40);
        self.statusLabel.textColor = [NSColor secondaryLabelColor];
        [window.contentView addSubview:self.statusLabel];

        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"主菜单"];
        NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:@"Mac新建文件" action:NULL keyEquivalent:@""];
        NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Mac新建文件"];
        [appMenu addItemWithTitle:@"退出 Mac新建文件" action:@selector(terminate:) keyEquivalent:@"q"];
        appItem.submenu = appMenu;
        [menu addItem:appItem];
        NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"编辑" action:NULL keyEquivalent:@""];
        NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"编辑"];
        [editMenu addItemWithTitle:@"撤销" action:@selector(undo:) keyEquivalent:@"z"];
        [editMenu addItem:[NSMenuItem separatorItem]];
        [editMenu addItemWithTitle:@"剪切" action:@selector(cut:) keyEquivalent:@"x"];
        [editMenu addItemWithTitle:@"复制" action:@selector(copy:) keyEquivalent:@"c"];
        [editMenu addItemWithTitle:@"粘贴" action:@selector(paste:) keyEquivalent:@"v"];
        [editMenu addItemWithTitle:@"全选" action:@selector(selectAll:) keyEquivalent:@"a"];
        editItem.submenu = editMenu;
        [menu addItem:editItem];
        NSApp.mainMenu = menu;
    }
    [self.settingsWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)setStatus:(NSString *)message success:(BOOL)success {
    self.statusLabel.stringValue = message;
    self.statusLabel.textColor = success ? [NSColor secondaryLabelColor] : [NSColor systemRedColor];
}

- (void)saveSettings:(id)sender {
    NSError *error = nil;
    NSArray<NSString *> *extensions = MFParseExtensions(self.extensionsEditor.string, &error);
    if (!extensions || !MFSaveExtensions(extensions, &error)) {
        [self setStatus:error.localizedDescription ?: @"保存失败，请检查后缀后重试。" success:NO];
        return;
    }
    self.extensionsEditor.string = [extensions componentsJoinedByString:@"\n"];
    [self setStatus:@"已保存，下次打开 Finder 右键菜单时生效。" success:YES];
}

- (void)restoreDefaults:(id)sender {
    NSError *error = nil;
    NSArray<NSString *> *extensions = MFDefaultExtensions();
    if (!MFSaveExtensions(extensions, &error)) {
        [self setStatus:error.localizedDescription ?: @"恢复默认失败，请重试。" success:NO];
        return;
    }
    self.extensionsEditor.string = [extensions componentsJoinedByString:@"\n"];
    [self setStatus:@"已恢复并保存默认后缀：txt、md、csv、sql。" success:YES];
}

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    self.receivedURL = YES;
    for (NSURL *url in urls) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        if (![components.scheme isEqualToString:@"localnewfile"] || components.user ||
            components.password || components.port || components.fragment ||
            (components.path.length && ![components.path isEqualToString:@"/"])) {
            ShowError(@"无法识别的新建文件请求。");
            continue;
        }
        if ([components.host isEqualToString:@"settings"] && !components.query && !components.path.length) {
            [self showSettings];
            continue;
        }
        if (![components.host isEqualToString:@"create"]) {
            ShowError(@"无法识别的新建文件请求。");
            continue;
        }
        NSMutableDictionary<NSString *, NSString *> *parameters = [NSMutableDictionary dictionary];
        BOOL valid = YES;
        for (NSURLQueryItem *item in components.queryItems) {
            if (![@[@"directory", @"extension"] containsObject:item.name] ||
                !item.value || parameters[item.name]) {
                valid = NO;
                break;
            }
            parameters[item.name] = item.value;
        }
        if (!valid || parameters.count != 2) {
            ShowError(@"请求必须包含唯一的目标文件夹和文件类型参数。");
            continue;
        }
        NSURL *createdURL = CreateEmptyFile(parameters[@"directory"], parameters[@"extension"]);
        if (createdURL) {
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[createdURL]];
        }
    }
    [self terminateIfSettingsClosed:application];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (!self.receivedURL) {
            [self showSettings];
        }
    });
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self showSettings];
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        __attribute__((objc_precise_lifetime)) AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [application run];
    }
    return 0;
}
