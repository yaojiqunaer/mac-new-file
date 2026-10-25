#define main MacNewFileApplicationMain
#import "Host.m"
#undef main

int main(void) {
    @autoreleasepool {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"local.codex.LocalNewFile.Tests"];
        [defaults removePersistentDomainForName:@"local.codex.LocalNewFile.Tests"];
        NSError *error = nil;
        NSArray *extensions = @[@"txt",@"md",@"csv",@"sql",@"json"];
        if (!MFSaveExtensions(extensions, &error)) return 1;
        NSString *cache = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        NSString *root = [cache stringByAppendingPathComponent:@"MacNewFileTests"];
        [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) return 2;
        NSString *template = [root stringByAppendingPathComponent:@"files-XXXXXX"];
        char *buffer = strdup(template.fileSystemRepresentation);
        char *created = mkdtemp(buffer);
        if (!created) { free(buffer); return 2; }
        NSString *directory = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:created length:strlen(created)];
        free(buffer);
        for (NSString *extension in extensions) {
            NSString *original = [directory stringByAppendingPathComponent:[@"新建文件." stringByAppendingString:extension]];
            [@"不得覆盖的原文件" writeToFile:original atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if (error) return 3;
            NSURL *result = CreateEmptyFile([NSURL fileURLWithPath:directory isDirectory:YES].absoluteString, extension);
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:result.path error:&error];
            NSString *expected = [NSString stringWithFormat:@"新建文件 1.%@",extension];
            if (!result || error || ![result.lastPathComponent isEqualToString:expected] ||
                [attributes[NSFileSize] unsignedLongLongValue] != 0 ||
                [attributes[NSFilePosixPermissions] unsignedIntegerValue] != 0600 ||
                ![[NSString stringWithContentsOfFile:original encoding:NSUTF8StringEncoding error:nil] isEqualToString:@"不得覆盖的原文件"]) return 4;
            printf("PASS %s custom-allowlist, empty-file, no-overwrite, duplicate-number, mode-0600\n", extension.UTF8String);
        }
        [defaults removePersistentDomainForName:@"local.codex.LocalNewFile.Tests"];
        [defaults synchronize];
        [[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
        return 0;
    }
}
