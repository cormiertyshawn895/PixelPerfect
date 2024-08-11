<a href="https://github.com/cormiertyshawn895/PixelPerfect/releases/download/1.4/PixelPerfect.1.4.zip" alt="Download Pixel Perfect"><img src="PixelPerfect/Screenshots/icon.png" width="150" alt="Pixel Perfect App icon" align="left"/></a>

<div>
<h2>Pixel Perfect</h2>
<p>Pixel Perfect lets you increase the text size of iPhone and iPad apps on Mac. Say goodbye to small and blurry text, and enjoy pixel-perfect graphics, all rendered at 100% native resolution.
</div>


<p align="center">
  <a href="https://github.com/cormiertyshawn895/PixelPerfect/releases/download/1.4/PixelPerfect.1.4.zip" alt="Download Pixel Perfect"><img width="240" src="PixelPerfect/Screenshots/resources/download-button.png" alt="Download Pixel Perfect"></a>
<p>
<p align="center">
  <a href="https://github.com/cormiertyshawn895/PixelPerfect/releases" alt="View Release Page"><img width="160" src="PixelPerfect/Screenshots/resources/release-button.png" alt="View Release Page"></a>
</p>

![](PixelPerfect/Screenshots/screenshot-animation.gif)

Since its inception, Pixel Perfect has been featured by [AAPL Ch.](https://applech2.com/archives/20230508-pixelperfect-iphone-and-ipad-apps-on-mac.html), [appgefahren.de](https://www.appgefahren.de/pixel-perfect-mac-app-optimiert-mobile-anwendungen-334908.html), [AppStories](https://appstories.net/episodes/326), [Christopher Lawley](https://www.youtube.com/watch?v=phNcKFkTG9s), [Club MacStories](https://club.macstories.net/posts/monthly-log-april-2023), [FLIP.de](https://flip.de/pixel-perfect-mac/), [Mac & i](https://www.heise.de/news/Bessere-Lesbarkeit-Tool-vergroessert-iPhone-und-iPad-Apps-auf-dem-Mac-8516352.html), and [ifun.de](https://www.ifun.de/pixel-perfect-fuer-iphone-und-ipad-apps-auf-dem-mac-207292).

---

### Opening Pixel Perfect

After downloading Pixel Perfect, double click to open it. macOS may prompt you “Pixel Perfect cannot be opened because it is from an unidentified developer.” This is expected.

To open Pixel Perfect, navigate to System Settings > Privacy & Security, then scroll down and click [“Open Anyway”](https://support.apple.com/102445#openanyway).

![](PixelPerfect/Screenshots/screenshot-gatekeeper.jpg)

Pixel Perfect will not harm your Mac. This alert shows up because Pixel Perfect is not notarized. Pixel Perfect is [open source](https://github.com/cormiertyshawn895/PixelPerfect), so you can always [examine its source code](https://github.com/cormiertyshawn895/PixelPerfect/tree/master/PixelPerfect) to verify its inner working.

---

### Using Pixel Perfect

On macOS Sonoma and later, Pixel Perfect will ask you to enable Full Disk Access. This is required for utilities such as Pixel Perfect to access and change the settings of other apps.

![](PixelPerfect/Screenshots/screenshot-full-disk-access.jpg)

By default, iPhone and iPad apps run at 77% scaling on your Mac. In some apps, this may result in small and blurry text. To improve legibility, click the toggle to run your favorite app at native resolution.

![](PixelPerfect/Screenshots/screenshot-disabled.jpg)

When iPhone and iPad app run at native resolution, you will experience pixel-perfect graphics, as well as text that are larger and sharper.

![](PixelPerfect/Screenshots/screenshot-enabled.jpg)

You can also choose “Enable All”. This makes all currently installed iPhone and iPad apps run at native resolution.

![](PixelPerfect/Screenshots/screenshot-enable-all.jpg)

![](PixelPerfect/Screenshots/screenshot-apps.gif)

---

### Frequently Asked Questions

#### Can I use Pixel Perfect on Mac computers with Apple silicon?

Yes, Pixel Perfect is fully compatible with Mac computers with Apple Silicon.

#### Can I use Pixel Perfect with iPhone and iPad apps downloaded from the Mac App Store?

Yes, you can use Pixel Perfect with iPhone and iPad apps downloaded from the Mac App Store. You can find iPhone and iPad apps by looking for “Designed for iPad” and “Designed for iPhone” in Mac App Store listings.

#### Can I use Pixel Perfect with iPhone and iPad apps downloaded from third party websites, PlayCover, or Sideloadly?

Yes, you can use Pixel Perfect with iPhone and iPad apps downloaded from third party websites or installed through utilities such as [PlayCover](https://playcover.io) and [Sideloadly](https://sideloadly.io). For apps incompatible with [PlayCover](https://playcover.io) and [Sideloadly](https://sideloadly.io), advanced users have the option to directly install them using Pixel Perfect. 

In Pixel Perfect, open the File menu and choose “Install Decrypted IPA” to get started. Then, you will be guided to [turn off System Integrity Protection](https://cormiertyshawn895.github.io/instruction/?arch=sip-as-lowering) to maximize app compatibility. After turning off System Integrity Protection, iPhone and iPad apps downloaded from the App Store will no longer open, therefore you can only install and use decrypted iPhone and iPad apps. As a result, this advanced feature works best in a [virtual Mac](https://cormiertyshawn895.github.io/instruction/?arch=sip-as-vm-lowering) through [UTM](https://mac.getutm.app/), [VirtualBudy](https://github.com/insidegui/VirtualBuddy/releases), and [Parallels Desktop](https://www.parallels.com/products/desktop/), [macOS on a separate APFS volume](https://support.apple.com/HT208891), or if you have already turned off System Integrity Protection for other reasons.

#### Can I use Pixel Perfect with Mac Catalyst apps?
Pixel Perfect only shows iPhone and iPad apps by default, but you can manually add Mac Catalyst apps in Pixel Perfect. 

Keep in mind that there are two types of Mac Catalyst apps. Mac Catalyst (Scaled to Match iPad), and Mac Catalyst (Optimized for Mac). Apps built with Mac Catalyst (Optimized for Mac) already run at native resolution, so Pixel Perfect is not applicable. If you want to run a Mac Catalyst (Scaled to Match iPad) app at native resolution, click “Add App” and manually choose the app. 

Twitter is not compatible with Pixel Perfect.

#### Can I use Pixel Perfect on Intel-based Mac?

With an Intel-based Mac, you can manually add Mac Catalyst (Scaled to Match iPad) app into Pixel Perfect to run them at native resolution.

#### Why does Pixel Perfect require Full Disk Access?

On macOS Sonoma and later, Full Disk Access is required for utilities such as Pixel Perfect to access and change the settings of other apps.

#### Can I run iPhone and iPad apps at native resolution without using Pixel Perfect?

Yes, but only for a small subset of iPhone and iPad apps. You need to use Pixel Perfect to run most iPhone and iPad apps at native resolution.

If the app listing shows “Designed for iPhone” (e.g: [Castro](https://apps.apple.com/app/id1080840241)), you can run it at native resolution without using Pixel Perfect. Open the app, click the “Window” menu, and choose “Zoom”. This also works on a small number of iPad apps that don’t support Split View, such as [Hypic](https://apps.apple.com/app/id1644042837).

---

### Troubleshooting Tips

#### Why are iPhone and iPad apps not showing up in the list?

Pixel Perfect relies on the Spotlight index on your Mac to determine which iPhone and iPad apps are installed. If Spotlight is still indexing your Mac, or you have turned off Spotlight indexing, you can click “Add App” and manually choose an iPhone or iPad app.

#### When asked by Pixel Perfect, I chose to quit and reopen the iPhone or iPad app later. Why didn’t my changes take effect after reopening the app?

Closing an iPhone or iPad app on the Mac often does not immediately quit the app. Instead, the app keeps running in the background for a short period of time. For changes to take effect immediately, you should choose “Quit & Reopen” when Pixel Perfect asks you. If you chose “Later”, you can open the Apple menu > Force Quit…, then Force Quit and reopen the iPhone or iPad app for changes to take effect immediately.

#### I already enabled native resolution for all apps, why do newly installed apps still run at scaled resolution?

When enabling native resolution for all apps, changes are only applied to apps that are installed at the moment. After you install new iPhone or iPad apps, open Pixel Perfect again to enable native resolution for newly installed apps.
