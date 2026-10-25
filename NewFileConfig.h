#import <Foundation/Foundation.h>

NSArray<NSString *> *MFDefaultExtensions(void);
NSArray<NSString *> *MFParseExtensions(NSString *text, NSError **error);
NSArray<NSString *> *MFLoadExtensions(void);
BOOL MFSaveExtensions(NSArray<NSString *> *extensions, NSError **error);
NSString *MFTitleForExtension(NSString *extension);
