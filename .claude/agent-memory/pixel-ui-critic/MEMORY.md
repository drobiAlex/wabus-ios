# WaBus iOS App — UI/UX Architecture Memory

## Design System (Current State)

### Color Palette
- **Bus:** `Color(red: 0.20, green: 0.48, blue: 1.0)` — light blue
- **Tram:** `Color(red: 1.0, green: 0.27, blue: 0.35)` — red/pink
- **Accent:** Yellow for favourites (star icon)
- **Materials:** `.ultraThinMaterial`, `.regularMaterial` used heavily for glassmorphic backgrounds

### Spacing System (STANDARDIZED ✓)
- Design tokens in `DS.Spacing`: xs(4pt), sm(8pt), md(16pt), lg(24pt), xl(32pt)
- Clean 4pt grid — no more random 10pt/12pt/20pt values

### Typography Scale (STANDARDIZED ✓)
- Design tokens in `DS`: caption(11pt), small(13pt), body(15pt), headline(17pt), display(22pt)
- All use `.rounded` design with appropriate weights
- Collapsed from 12 sizes down to 5 core sizes

### Corner Radii (STANDARDIZED ✓)
- Design tokens in `DS.Radius`: sm(8pt), md(16pt)
- Capsule used for pill shapes
- No more inconsistent 6pt/12pt/14pt/20pt values

## Component Library

### Map Annotations
- **VehicleAnnotationView**: Capsule with icon + line number + optional heading chevron
  - Issue: No visual state for "selected" vehicle
- **StopAnnotationView**: 24×24pt white circle with 2.5pt blue stroke + blue mappin icon
  - CRITICAL: Hardcoded `.blue` (line 14, 19) — never uses route/vehicle type color
  - Issue: Blue-on-blue visual chaos when showing bus routes
  - Issue: Redundant icon (mappin already implied by position)
  - See `route-visualization.md` for full critique
- **ClusterAnnotationView**: Circle with count (NOT interactive — should be)

### Bottom UI Elements
- **FilterBarView**: Always-visible horizontal scroll with bus/tram toggles + favourite lines + plus button
- **VehicleRouteBar**: Conditionally visible when vehicle selected (competes visually with FilterBarView)
  - Issue: Both use similar visual treatment, causing hierarchy conflict

### Sheets
- **VehicleDetailSheet**: Shows vehicle metadata (vehicle number, brigade, updated time, coordinates)
  - Issue: Brigade and coordinates are useless to users
- **StopScheduleView**: Shows upcoming arrivals with line filter pills
  - Issue: Double-filtering UX feels disconnected
- **LineListView**: Grouped list of all bus/tram lines with search

### Status Indicators
- **ConnectionStatusView**: Dot indicator (green/yellow/white) with optional "Reconnecting..." text
  - Issue: Connected state (8pt dot) is too subtle

## Interaction Patterns

### Vehicle Selection Flow
1. Tap vehicle on map → VehicleRouteBar appears
2. Tap info button on route bar → VehicleDetailSheet opens
3. Tap X on route bar → deselect, bar disappears

**Issue:** No visual feedback on map annotation when selected

### Favouriting (3 different UX patterns)
1. VehicleRouteBar: Icon-only star button
2. VehicleDetailSheet: Full-width labeled button
3. LineListView: Icon-only star button

**Issue:** Inconsistent patterns for same action

### Hidden Interactions
- Long-press favourite chip in FilterBarView → context menu to remove
  - Issue: Zero discoverability, no visual hint

## Accessibility Gaps

### Touch Target Failures (<44×44pt)
- Filter pills: ~40×32pt
- Connection status dot: ~20×20pt
- Stop annotations: 32×32pt

### Missing Accessibility Labels
- No `.accessibilityLabel()` modifiers anywhere
- VoiceOver will read SF Symbol names ("Bus.fill") instead of meaningful descriptions

## Performance Considerations

### Clustering
- Uses grid-based clustering (10×10 grid based on visible region)
- Caps at 150 annotations (`maxAnnotations` in MapViewModel)
- Prioritizes selected/favourite lines when capping

### Caching
- Route shapes cached by line with 10-min TTL: `[String: (shapes: [RouteShape], fetchedAt: Date)]`
- Route stops cached by line with 10-min TTL: `[String: (stops: [Stop], fetchedAt: Date)]`
- Favourite vehicles refreshed every 60 seconds

### Route Rendering (MapContentView.swift)
- Polylines: 4pt stroke at 0.8 opacity (line 11)
- Issue: Insufficient prominence, washed out appearance
- Issue: All routes same visual weight (no hierarchy for selected vehicle)
- See `route-visualization.md` for fixes

## Common Anti-Patterns Found

1. **Data dumping**: Showing raw data (brigade, coordinates) without user value
2. **Visual hierarchy conflicts**: Multiple prominent UI elements competing for attention
3. **Hidden affordances**: Important actions (remove favourite) hidden behind gestures
4. **Inconsistent patterns**: Same action (favouriting) with different UX in different contexts
5. **Over-specification**: Too many font sizes, spacing values, corner radii

## Recommended Next Steps (If Asked)

1. **Establish visual hierarchy**: Dim FilterBarView when VehicleRouteBar is visible
2. **Add selection states**: Vehicle annotations should visually indicate selection
3. **Fix touch targets**: Ensure all interactive elements meet 44×44pt minimum
4. **Prune useless data**: Remove brigade and coordinates from detail sheet
5. **Standardize design tokens**: Collapse font sizes, spacing, and radii to coherent scales
6. **Add accessibility labels**: Meaningful VoiceOver descriptions for all interactive elements
