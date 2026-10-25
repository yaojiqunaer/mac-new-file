#import <Foundation/Foundation.h>
#import "NewFileConfig.h"
int main(void) { @autoreleasepool {
    NSError *error = nil;
    if (!MFSaveExtensions(MFDefaultExtensions(), &error) || ![MFLoadExtensions() isEqual:MFDefaultExtensions()]) {
        fprintf(stderr, "FAIL bundled owner preferences: %s\n", error.localizedDescription.UTF8String);
        return 1;
    }
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:@"local.codex.LocalNewFile.Tests"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    puts("PASS bundled owner preferences");
    return 0;
} }
