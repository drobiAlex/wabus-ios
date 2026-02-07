# WaBus iOS App — UI/UX Architecture Memory

## Design System (Current State)

### Color Palette
- **Bus:** `Color(red: 0.20, green: 0.48, blue: 1.0)` — light blue
- **Tram:** `Color(red: 1.0, green: 0.27, blue: 0.35)` — red/pink
- **Accent:** Yellow for favourites (star icon)
- **Materials:** `.ultraThinMaterial`, `.regularMaterial` used heavily for glassmorphic backgrounds

### Spacing System (INCONSISTENT — needs cleanup)
- Current values: 4pt, 8pt, 10pt, 12pt, 16pt, 20pt, 24pt
- **Recommendation:** Standardize to 8pt grid (0, 8, 16, 24, 32) or strict 4pt increments

### Typography Scale (TOO MANY SIZES)
- Current: 10pt, 11pt, 12pt, 13pt, 14pt, 15pt, 16pt, 18pt, 20pt, 22pt (12 sizes!)
- **Recommendation:** Collapse to 5 sizes: 11pt (caption), 13pt (secondary), 15pt (body), 17pt (headline), 22pt (display)

### Corner Radii (INCONSISTENT)
- Current: 6pt, 8pt, 12pt, 14pt, 16pt, 20pt, Capsule
- **Recommendation:** Standardize to 8pt (cards/buttons), 16pt (panels), Capsule (pills)

## Component Library

### Map Annotations
- **VehicleAnnotationView**: Capsule with icon + line number + optional heading chevron
  - Issue: No visual state for "selected" vehicle
- **StopAnnotationView**: Circle with bus.fill icon (hardcoded, should be generic)
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
- Route shapes cached by line (`routeShapesCache: [String: [RouteShape]]`)
- Route stops cached by line (`routeStopsCache: [String: [Stop]]`)
- Favourite vehicles refreshed every 30 seconds

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
