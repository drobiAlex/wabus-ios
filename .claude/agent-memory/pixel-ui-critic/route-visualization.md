# Route Visualization Issues (Feb 2026)

## Stop Annotation Problems

### Current Implementation (`StopAnnotationView.swift`)
- 24×24pt white circle with 2.5pt blue stroke
- `mappin.circle.fill` icon hardcoded to blue
- No visual state for selection
- Touch target artificially expanded to 44×44pt with invisible halo
- Hardcoded blue color (line 14, 19) — NEVER uses route color

### Critical Issues
1. **Blue-on-blue visual chaos** — Bus routes are blue, stop markers are blue, map has blue water/roads
2. **Visual spam** — 40+ identical blue dots on screen when route is selected
3. **No color context** — Stops don't inherit route color (should be red for trams, blue for buses)
4. **Redundant icon** — Mappin icon conveys zero information (position already shown by placement)
5. **Dishonest touch targets** — 24pt visual with 44pt tap zone creates invisible collision areas

### Recommended Fixes
- Pass `vehicleType: VehicleType` or `color: Color` to stop annotation
- Reduce to 12×12pt filled circle (no border, no icon) at 50% opacity
- Add `isSelected: Bool` parameter → scale to 32×32pt with white 3pt outline when selected
- Use route color or neutral gray (`Color(.systemGray)`) instead of hardcoded blue
- Make touch target match visual size (no invisible halos)

## Route Polyline Problems

### Current Implementation (`MapContentView.swift` line 10-12)
- 4pt line width at 0.8 opacity
- All polylines rendered at same visual weight
- No outline or separation from map

### Critical Issues
1. **Insufficient prominence** — Route line competes with map elements instead of dominating
2. **Washed out appearance** — 0.8 opacity makes it blend into background
3. **No visual hierarchy** — Selected vehicle's route looks identical to other routes

### Recommended Fixes
- Increase line width to 6pt (or 7pt on smaller screens)
- Use full 1.0 opacity for route polyline
- Add white outline underneath (8pt, 0.5 opacity) for separation
- When vehicle selected, dim other polylines to 0.3 opacity
- Consider animated dashes or pulsing for active route

## Color System Issues

### Current State
- Bus: `Color(red: 0.20, green: 0.48, blue: 1.0)` (light blue)
- Tram: `Color(red: 1.0, green: 0.27, blue: 0.35)` (red/pink)
- Stops: Hardcoded `.blue` (not using vehicle type colors)
- Route polylines: Use `lineColors[line]` from GTFS data OR fallback to vehicle type color

### Issue
Stop annotations ignore the color system entirely. Line 14 and 19 in `StopAnnotationView.swift` hardcode blue.

## Progressive Disclosure Opportunity

Current behavior: Show ALL stops for selected route at once.

Recommendation:
- At high zoom levels (far out), hide stops entirely — only show route polyline
- At medium zoom, show every 3rd or 5th stop
- At close zoom, show all stops
- Use map region's `latitudeDelta` to determine zoom level

This reduces visual clutter and makes the map scannable at different zoom levels.
