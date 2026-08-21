# Ben Simulated Phone

Ben is an in-app phone world, not a carrier-number product. Every AI companion behaves like a contact in a private simulated phone network.

## Demo flow

1. Open Ben and tap an AI friend. The outgoing-call screen rings, the friend answers, and the conversation opens.
2. Speak naturally. Ben listens automatically after speaking, transcribes the user, generates a response, and speaks it back with the contact’s personality.
3. Say a request such as “Call me at 2 PM and remind me about my meeting.” The request is stored as a reminder, a local notification is scheduled, and the simulated phone engine schedules an incoming call from the correct AI contact.
4. At the scheduled time, Ben presents an incoming-call screen containing the reason for the call. Accepting it opens the voice conversation; declining or ignoring it records a missed/declined call.
5. The Recents tab shows simulated incoming and outgoing call history.

## Product boundary

The system intentionally does not require a real phone number, carrier account, or telecom provider. It simulates the full emotional and interaction model of a phone call inside the application. This keeps the product self-contained, demonstrable, and safe to prototype while preserving the core breakthrough idea: AI companions that proactively call the user instead of waiting for a chat message.

## Important runtime behavior

The scheduler works while the app process is active, and local notifications provide a reminder when the operating system suspends the app. For a production mobile release, notification-tap routing should be added so tapping a reminder notification opens the simulated incoming-call screen even after the app was fully terminated.


## Natural multilingual calling

Each friend can have a preferred conversation language: English, French, Spanish, Mandarin Chinese, German, or Kiswahili. Ben configures speech recognition and text-to-speech for that language and instructs the conversation model to reply in the same language unless the user switches.

The call state machine is deliberately turn-based. The friend speaks first, then the microphone opens. Partial recognition is shown as a live transcript, but Ben does not send text to the model until speech recognition has closed after the user finishes speaking or taps stop. Only then does the app enter thinking state and generate a reply.

## Voice profile safety

Ben supports distinct built-in voice characters and stores consent metadata for future authorized voice profiles. A real person’s voice must not be cloned from a recording without that person’s explicit permission. Memorial or friend-inspired profiles must disclose that the voice is AI-generated and must never be presented as the actual person.
