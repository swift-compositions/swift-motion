#if Command
    @_exported public import Motion
    @_exported public import Motion_Picture
    @_exported public import Picture
    @_exported public import Timeline
    #if canImport(AVFoundation)
        @_exported public import Motion_Encoding
    #endif
#endif
