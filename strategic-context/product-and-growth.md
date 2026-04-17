# Strategic Context: Product & Growth

## Theme

Understanding Human Health's product, monetisation, and growth dynamics — the domain knowledge that shapes how analytics and personalisation projects should be framed.

## Subscription Model

**HumanPlus** (paid tier) launched Feb 10, 2025. Before that the app was entirely free. There have never been free trials.

Key data caveats:
- Always split subscription analysis by monthly vs annual
- Product IDs map 1:1 to prices (different for iOS vs Android) — segment by product ID, never average blindly
- Pricing experiments mean same-cohort users may have different prices
- Only count users active after Feb 10, 2025 in conversion denominators
- Feb 2026 spike was global marketing expansion (cheap emerging market users, low quality) — segment by country/market
- Regional pricing uses purchasing power parity — prices vary by market on top of A/B experiments

## Upsell Landscape

Current conversion mechanisms (as of 2026-03):

1. **Onboarding upsell screen** (~mid-2025): Early in onboarding flow. Primary conversion driver — most subs happen in first session.
2. **Passive CTAs** around the app: Low click volume, single-digit conversion.
3. **Patterns as active upsell**: Push notification → free pattern taste → upgrade CTA. Main lever for converting established free users, but below expectations.

The free-to-paid path for long-term users is broken — only a tiny fraction convert after 90+ days. Building more active conversion paths is a current priority (modal interstitials, push notifications, email campaigns).

## Paid Product Value Gap

HumanPlus doesn't add enough incremental value over free. This is a recognised product problem, not just a marketing/upsell problem. New paid features are actively being built.

Implication: conversion optimisation has a ceiling until the product improves. Don't over-attribute low conversion to UX/funnel problems alone.

## Growth Strategy

ASA (Apple Search Ads) converts best (5-7%) but is search-volume capped — 80-90% share of voice already captured. Not budget limited, reach limited.

Strategy is shifting toward organic channels: traditional SEO, AI search engine visibility (ChatGPT, Perplexity), and organic social content to reduce over-reliance on paid ads.

Paid social (TikTok, Meta) drives volume but at low conversion (1-3%). Don't recommend "shift budget to ASA" — it's maxed out.

## Attribution

iOS uses SKAdNetwork — only ASA has reliable user-level attribution. TikTok vs Meta split on iOS is modelled/estimated by AppsFlyer and unreliable. Android attribution is user-level and trustworthy.

Always segment traffic as: ASA / non-ASA paid (lumped) / unknown-organic. Never rely on TikTok vs Meta distinction on iOS.

## Notification Strategy

The core notification problem is signal-to-noise, not message quality. Too many product push notifications drown out everything else. The primary lever is total volume reduction, with smarter targeting as secondary.

Don't frame notification analysis as "which messages to optimise." Frame it as "what's the total notification budget and how should it be allocated."

## Content Strategy

Static blog articles aren't viable long-term — need thousands to select appropriately vs AI-generated genuinely personalised content. The home page is being redesigned with content in a different placement. Don't over-invest in optimising current static content selection.

## Segmentation Dimensions

Three critical dimensions for user segmentation:
1. **Acquisition source** (ASA vs paid social vs organic)
2. **Tenure/maturity** (D3/D7/D14/D21 cohorts)
3. **Health profile** (conditions, symptoms, treatments) — a critical third dimension that drives engagement patterns
