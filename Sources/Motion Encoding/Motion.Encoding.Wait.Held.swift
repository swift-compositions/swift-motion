import AVFoundation
import Motion

extension Motion.Encoding.Wait {
    /// One of AVFoundation's objects that is used a call at a time, held on a `Reader` of its own: a reader's
    /// provider, a writer's receiver, a writer. Its calls run on the reader's thread, one at a time and never
    /// concurrently, as AVFoundation asks; a call left behind past its limit keeps that thread, and the object
    /// is asked nothing more.
    actor Held<Value> {
        let value: Value
        nonisolated let reader: Motion.Encoding.Reader

        init(_ value: sending Value) {
            self.value = value
            self.reader = Motion.Encoding.Reader()
        }

        nonisolated var unownedExecutor: UnownedSerialExecutor {
            unsafe reader.asUnownedSerialExecutor()
        }
    }
}

extension Motion.Encoding.Wait.Held where Value == Motion.Encoding.Samples {
    // swift-linter:disable:next untyped throws
    // REASON: the provider's next() throws untyped; the public calls type it.
    /// The provider's next sample.
    func next() async throws -> CMReadySampleBuffer<CMSampleBuffer.DynamicContent>? {
        try await value.next()
    }
}

extension Motion.Encoding.Wait.Held where Value == AVAssetWriterInput.SampleBufferReceiver {
    // swift-linter:disable:next untyped throws
    // REASON: the receiver's append throws untyped; score types it.
    /// The sample appended to the writer's input.
    func append(_ sample: CMReadySampleBuffer<CMSampleBuffer.DynamicContent>) async throws {
        try await value.append(sample)
    }

    /// The writer's input finished.
    func finish() {
        value.finish()
    }
}

extension Motion.Encoding.Wait.Held where Value == AVAssetWriterInput.PixelBufferReceiver {
    // swift-linter:disable:next untyped throws
    // REASON: the receiver's append and CVMutablePixelBuffer throw untyped; write types them.
    /// A frame copied into a pixel buffer, from the receiver's pool where it has one, and appended at `time`.
    func append(_ frame: Raster<Motion.Pixel>, at time: CMTime, attributes: CVPixelBufferCreationAttributes) async throws {
        var buffer = if let pool = value.pixelBufferPool { try pool.makeMutablePixelBuffer() } else { try CVMutablePixelBuffer(attributes) }
        Motion.Encoding.copy(frame, into: &buffer)
        try await value.append(CVReadOnlyPixelBuffer(buffer), with: time)
    }

    /// The writer's input finished.
    func finish() {
        value.finish()
    }
}

extension Motion.Encoding.Wait.Held where Value == AVAssetWriter {
    /// The writer finished: nil when it completed, and otherwise why not.
    func finish() async -> String? {
        await withCheckedContinuation { finished in value.finishWriting { finished.resume() } }
        return value.status == .completed ? nil : value.error?.localizedDescription ?? "not completed"
    }
}
