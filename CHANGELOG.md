# Changelog

All notable changes to Haze.

## 0.1.2 — Close, open or both
- **Plays on close, open or both:** Settings → Plays on. Close Only hazes the screen as the lid goes down and simply gets out of the way when it opens; Open Only leaves closing alone and clears the haze as the lid opens.
- **Far lighter on the battery:** at rest Haze reads the lid sensor 5 times a second instead of 15, and not at all while the display sleeps or Haze is off. It now uses about a fifth of the energy it did (~0.2 % CPU).
- **New defaults:** the haze starts at 91°, is full at 31°, clears 2 s after the lid stops, with 70 % dimming.
- **New icon:** the screen goes out of focus from the hinge up, which is what Haze does.
- A closed Settings window no longer keeps updating in the background.

## 0.1.1 — Just the haze
- A cleaner icon: the laptop's screen simply mists over from the top edge, with nothing else on it.
- Installing no longer leaves a second Haze in the project's build folder for Spotlight to find.

## 0.1.0 — First release
- The iPhone Duo's fold blur on a MacBook: close the lid and the screen frosts over and dims from the top edge down; open it and the haze clears.
- Follows the lid angle sensor live. No haze above the start angle, full at the full-haze angle, and opening only ever clears it.
- Settings: start and full-haze angles (with **Set** to use the lid's current angle), how long a still lid takes to clear, blur, dimming, preview and open at login.
