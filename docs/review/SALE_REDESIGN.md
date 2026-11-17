# Selling: rocks, arithmetic, totals

November 16, 2026. The owner rejects the previous sale UI and authorizes a full redesign around recognizable rocks, individual rewards, totals and modifier effects. This supersedes the earlier receipt/inspector layout. Routine shared Edit save only; no publication.

The candidate keeps four large rocks per desktop page, two on narrow screens. Each object owns its name, base → final cash, named cash bonus and exact material rewards. Material modifiers show base → final and the named added amount. Plain rocks show only their payout. Amounts include the displayed stack quantity. One totals column sits to the right, moving below the rocks on narrow layouts; long material sets scroll. There are no separate inspector, receipt columns or visible addition histories.

Preview quotes the whole bag without crediting it. Confirmation retains authoritative server processing. Each rock briefly emphasizes its modifier before releasing colored particles into the corresponding total. Sold rocks remain slightly dimmed with their values intact. Both preview and the final result can be paged; the result stays until E, controller X, touch Close or Escape. Preview no longer closes merely because the player spent 44 seconds inspecting it; the server still rejects an unconfirmed quote after its 45-second validity window, so a fresh preview is needed then. Courier/nonmodal payout behavior remains intact. Reduced motion suppresses shake, token flights and size oscillation.

## Reference and interpretation

Inspected the [official Balatro press kit](https://www.playbalatro.com/press-kit/), including [its UI screenshot](https://www.playbalatro.com/press-kit/Screenshots/Balatro_ui_3840x2160_1.png) and [Combo 1](https://www.playbalatro.com/press-kit/Screenshots/Combo%201.png). The design inference is to keep the contributing object close to its number, emphasize one contribution at a time and give the final aggregate a stable location. This is a reference for hierarchy, not an assertion that copied styling or a specific animation timing is proven enjoyable. Existing original rocks, mineral colors and modifier effects are preserved.

## Evidence and limits

Native Edit component checks execute the production SaleView/SaleLedger modules without starting Play. Three mixed items completed in 2.88 seconds with exact $169 total, six peak currency particles and a 0.367-second modifier lead. A ten-item case with injected 430×800 layout dimensions completed in 7.26 seconds with exact $351 total. All rocks and values remained; paging to the final two items hid the first page, and final-page text bounds fit. This is layout arithmetic with actual Roblox font metrics, not device simulation or a phone screenshot.

`python3 tools/test_selling.py` passes server selling, Workshop, persistence, controller compilation and ledger integration checks. The mining chat updated the legacy shallow-stone-hop fixture to reflect the owner's new full-arc drop requirement; payout semantics are unchanged.

The Studio scene capture omits the temporary CoreGui sale overlay; native window access timed out. Therefore the complete composited appearance, natural-speed visual/audio quality, touch usability and multiplayer remain unverified. Temporary fixtures were cleaned and no agent-started Play occurred. The mining chat owns the combined seven-Source sync, canonical refresh and Git integration; consult PROJECT_STATE for the exact integrated revision and save evidence.
