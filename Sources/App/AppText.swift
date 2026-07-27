import Foundation

/// Fixed copy used across the app.
enum AppText {
    static let recordInstructions = """
    Let's capture your voice. When you're ready, tap the record button and read \
    the passage below in your natural speaking voice. Aim for about sixty to ninety \
    seconds in a quiet room — a longer, cleaner sample makes a much better result. \
    When you're done, you can play it back and confirm.
    """

    /// A compact, phonetically varied passage (~45–60s read aloud). Kept short so
    /// the record button stays visible; read slowly or twice for a longer sample.
    static let sampleScript = """
    Thanks for helping me set up my voice. I'll read this in my normal speaking \
    voice, at a calm, steady pace, as if I'm talking to a friend. The morning light \
    came through the kitchen window as the kettle began to whistle. I counted five \
    apples, three oranges, and a dozen eggs. Numbers like sixteen and forty-two should \
    sound natural, and so should everyday words: water, garden, music, and weather. \
    The quick brown fox jumps over the lazy dog. I keep my tone even, letting each \
    sentence flow into the next, so the app gets a clear picture of how I really sound.
    """
}
