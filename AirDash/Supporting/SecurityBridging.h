#ifndef SecurityBridging_h
#define SecurityBridging_h

#import <CoreFoundation/CoreFoundation.h>

// SecTaskCreateFromSelf/SecTaskCopyValueForEntitlement are public C functions
// of Security.framework (Security/SecTask.h), the standard way for a process
// to read its own code-signing entitlements at runtime. Swift doesn't bridge
// them on iOS (only on macOS), hence this manual declaration. CF_RETURNS_RETAINED
// lets Swift manage the resulting CFTypeRef as a regular Optional rather than
// an Unmanaged<> value.
CF_ASSUME_NONNULL_BEGIN
extern CFTypeRef _Nullable SecTaskCreateFromSelf(CFAllocatorRef _Nullable allocator) CF_RETURNS_RETAINED;
extern CFTypeRef _Nullable SecTaskCopyValueForEntitlement(
    CFTypeRef task,
    CFStringRef entitlement,
    CFErrorRef _Nullable *_Nullable error
) CF_RETURNS_RETAINED;
CF_ASSUME_NONNULL_END

#endif /* SecurityBridging_h */
