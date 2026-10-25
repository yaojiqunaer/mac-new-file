#import <Foundation/Foundation.h>
#import "NewFileConfig.h"

static void Require(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "FAIL %s\n", message.UTF8String); exit(1); }
}
int main(void) {
    @autoreleasepool {
        NSString *domain = @"local.codex.LocalNewFile.Tests";
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:domain];
        [defaults removePersistentDomainForName:domain];
        [defaults synchronize];
        Require([MFLoadExtensions() isEqual:MFDefaultExtensions()], @"初始默认四种格式");
        NSError *error = nil;
        NSArray *parsed = MFParseExtensions(@".TXT, md，csv\nsql JSON json  tar.gz", &error);
        Require([parsed isEqual:@[@"txt",@"md",@"csv",@"sql",@"json",@"tar.gz"]], @"混合分隔、大小写、去重及复合后缀");
        for (NSString *invalid in @[@"../sql", @"a/b", @"a\\b", @"a..b", @"; ,", @"$sql", @"-sql"]) {
            error = nil;
            Require(MFParseExtensions(invalid, &error) == nil && error != nil, @"拒绝非法或空后缀");
        }
        Require(MFSaveExtensions(parsed, &error), @"保存用户自定义类型");
        Require([MFLoadExtensions() isEqual:parsed], @"读取已保存类型");
        Require([MFTitleForExtension(@"json") containsString:@"json"], @"自定义类型菜单标题");
        Require(!MFSaveExtensions(@[@"txt",@"../bad"], &error), @"非法保存不能写入配置");
        Require([MFLoadExtensions() isEqual:parsed], @"非法保存保持原配置");
        [defaults setObject:@[@"../bad"] forKey:@"AllowedExtensions"];
        [defaults synchronize];
        Require([MFLoadExtensions() isEqual:MFDefaultExtensions()], @"损坏配置回退默认值");
        [defaults removePersistentDomainForName:domain];
        [defaults synchronize];
        puts("PASS config: defaults, parser, safety, persistence, invalid-write preservation, corrupt-data fallback");
    }
    return 0;
}
