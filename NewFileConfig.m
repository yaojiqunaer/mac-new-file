#import "NewFileConfig.h"

#ifndef MF_PREFERENCES_DOMAIN
#define MF_PREFERENCES_DOMAIN @"local.codex.LocalNewFile"
#endif

static NSString * const MFConfigKey = @"AllowedExtensions";

static NSUserDefaults *MFPreferences(void) {
    // 当前应用自己的偏好必须使用 standardUserDefaults；suiteName 只供扩展读取宿主域。
    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:MF_PREFERENCES_DOMAIN]) {
        return [NSUserDefaults standardUserDefaults];
    }
    return [[NSUserDefaults alloc] initWithSuiteName:MF_PREFERENCES_DOMAIN];
}

static void MFConfigError(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"MacNewFile.Configuration" code:1
        userInfo:@{NSLocalizedDescriptionKey:message}];
}

NSArray<NSString *> *MFDefaultExtensions(void) {
    return @[@"txt", @"md", @"csv", @"sql"];
}

NSArray<NSString *> *MFParseExtensions(NSString *text, NSError **error) {
    if (![text isKindOfClass:NSString.class]) {
        MFConfigError(error, @"请输入文件后缀。");
        return nil;
    }
    NSMutableCharacterSet *separators = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
    [separators addCharactersInString:@",，;；"];
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:
        @"^[a-z0-9][a-z0-9_-]*(\\.[a-z0-9][a-z0-9_-]*)*$" options:0 error:nil];
    NSMutableOrderedSet<NSString *> *values = [NSMutableOrderedSet orderedSet];
    for (NSString *raw in [text componentsSeparatedByCharactersInSet:separators]) {
        if (raw.length == 0) continue;
        NSString *value = raw.lowercaseString;
        if ([value hasPrefix:@"."]) value = [value substringFromIndex:1];
        if (value.length == 0 || value.length > 32 ||
            [pattern numberOfMatchesInString:value options:0 range:NSMakeRange(0,value.length)] != 1) {
            MFConfigError(error, @"后缀限 1–32 个字符，使用字母、数字、横线或下划线；可用点分隔复合后缀，如 tar.gz。不能包含路径符号。");
            return nil;
        }
        [values addObject:value];
        if (values.count > 64) {
            MFConfigError(error, @"最多保存 64 种文件后缀。");
            return nil;
        }
    }
    if (values.count == 0) {
        MFConfigError(error, @"请至少填写一种文件后缀。");
        return nil;
    }
    return values.array;
}

static NSArray<NSString *> *MFValidatedArray(id value, NSError **error) {
    if (![value isKindOfClass:NSArray.class]) {
        MFConfigError(error, @"文件后缀配置格式无效。");
        return nil;
    }
    for (id item in value) {
        if (![item isKindOfClass:NSString.class]) {
            MFConfigError(error, @"文件后缀必须是文本。");
            return nil;
        }
    }
    return MFParseExtensions([value componentsJoinedByString:@"\n"], error);
}

NSArray<NSString *> *MFLoadExtensions(void) {
    NSUserDefaults *defaults = MFPreferences();
    [defaults synchronize];
    id saved = [defaults objectForKey:MFConfigKey];
    if (!saved) return MFDefaultExtensions();
    return MFValidatedArray(saved, nil) ?: MFDefaultExtensions();
}

BOOL MFSaveExtensions(NSArray<NSString *> *extensions, NSError **error) {
    NSArray *validated = MFValidatedArray(extensions, error);
    if (!validated) return NO;
    NSUserDefaults *defaults = MFPreferences();
    [defaults setObject:validated forKey:MFConfigKey];
    if (![defaults synchronize]) {
        MFConfigError(error, @"文件后缀保存失败，请检查当前用户的配置目录权限。");
        return NO;
    }
    return YES;
}

NSString *MFTitleForExtension(NSString *extension) {
    NSDictionary *names = @{@"txt":@"文本文件", @"md":@"Markdown", @"csv":@"CSV", @"sql":@"SQL"};
    NSString *name = names[extension] ?: extension.uppercaseString;
    return [NSString stringWithFormat:@"%@ (.%@)", name, extension];
}
