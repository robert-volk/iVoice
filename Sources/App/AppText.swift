import Foundation

/// Fixed copy used across the app.
enum AppText {
    static let recordInstructions = """
    Let's capture your voice. When you're ready, tap the record button and read \
    the passage below in your natural speaking voice. Aim for about sixty to ninety \
    seconds in a quiet room — a longer, cleaner sample makes a much better result. \
    When you're done, you can play it back and confirm.
    """

    /// A longer, phonetically varied passage (~75–90s read aloud) for a
    /// representative sample. More clean audio yields a noticeably better clone.
    static let sampleScript = """
    Thank you for helping me set up my voice. I'll read this passage in my normal \
    speaking voice, at a comfortable, steady pace, as if I were talking to a friend. \
    The morning light came softly through the kitchen window while the kettle began \
    to whistle. I counted five apples, three oranges, and a dozen eggs before writing \
    out the week's grocery list. Numbers like sixteen, forty-two, and one hundred \
    should sound natural, and so should everyday words: water, garden, music, weather, \
    telephone, and thank you. Sometimes I ask a question, like where did the afternoon \
    go? Other times I simply pause, take a breath, and keep reading calmly. The quick \
    brown fox jumps over the lazy dog, and that phrase gives every letter a moment to \
    breathe. When I speak, I try to keep my tone even — neither rushed nor sleepy — \
    letting each sentence flow into the next. This longer sample gives the app a rich \
    and accurate picture of how I really sound: my rhythm, my pitch, and the small \
    details that make my voice my own. That should be more than enough to work with.
    """
}
