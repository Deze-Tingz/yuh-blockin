# Claude Code Guidelines for Yuh Blockin'

## Project Overview
Flutter app for vehicle alerts/notifications. Premium UI with animations.

---

## UI OVERFLOW PREVENTION RULES (CRITICAL)

These rules MUST be followed to prevent overflow errors on different screen sizes.

### 1. Text in Row - ALWAYS use Flexible/Expanded
```dart
// BAD - Will overflow on small screens
Row(
  children: [
    Icon(Icons.car),
    Text('This is a very long license plate description'),
  ],
)

// GOOD - Text will wrap or ellipsis
Row(
  children: [
    Icon(Icons.car),
    Flexible(
      child: Text(
        'This is a very long license plate description',
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
)
```

### 2. User-Facing Text - ALWAYS add overflow handling
```dart
// BAD - Long text will overflow
Text(userInput)

// GOOD - Handles long content gracefully
Text(
  userInput,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
)
```

### 3. Column with Multiple Children - Consider ScrollView
```dart
// BAD - Will overflow if content exceeds screen
Column(
  children: [
    Widget1(),
    Widget2(),
    Widget3(),
    // ... many widgets
  ],
)

// GOOD - Scrollable when needed
SingleChildScrollView(
  child: Column(
    children: [
      Widget1(),
      Widget2(),
      Widget3(),
    ],
  ),
)
```

### 4. Responsive Layouts - Use LayoutBuilder
```dart
// GOOD - Adapts to available space
LayoutBuilder(
  builder: (context, constraints) {
    final isCompact = constraints.maxHeight < 600;
    final isTablet = constraints.maxWidth > 600;

    return Column(
      children: [
        SizedBox(height: isCompact ? 8 : 16),
        // ... rest of layout
      ],
    );
  },
)
```

### 5. Bottom Content - Account for Safe Area
```dart
// BAD - Gets cut off by system navigation
Padding(
  padding: EdgeInsets.only(bottom: 12),
  child: FooterWidget(),
)

// GOOD - Respects system UI
Padding(
  padding: EdgeInsets.only(
    bottom: MediaQuery.of(context).padding.bottom + 12,
  ),
  child: FooterWidget(),
)
```

### 6. Fixed Sizes - Avoid or Use Constraints
```dart
// BAD - Breaks on small screens
Container(
  height: 400,
  child: Content(),
)

// GOOD - Flexible with max constraint
ConstrainedBox(
  constraints: BoxConstraints(maxHeight: 400),
  child: Content(),
)
```

### 7. ListView in Column - Use Expanded or shrinkWrap
```dart
// BAD - Unbounded height error
Column(
  children: [
    Header(),
    ListView(...),  // ERROR!
  ],
)

// GOOD - Option 1: Expanded
Column(
  children: [
    Header(),
    Expanded(
      child: ListView(...),
    ),
  ],
)

// GOOD - Option 2: shrinkWrap (for short lists only)
Column(
  children: [
    Header(),
    ListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      ...
    ),
  ],
)
```

### 8. Images - Always constrain
```dart
// BAD - Image might be huge
Image.asset('path/to/image.png')

// GOOD - Constrained size
Image.asset(
  'path/to/image.png',
  width: 100,
  height: 100,
  fit: BoxFit.contain,
)
```

---

## SCREEN SIZE BREAKPOINTS

Use these consistently across the app:

```dart
// In LayoutBuilder or MediaQuery:
final screenWidth = MediaQuery.of(context).size.width;
final screenHeight = MediaQuery.of(context).size.height;

final isCompact = screenHeight < 700;      // Small phones (iPhone SE, etc.)
final isTablet = screenWidth > 600;        // Tablets
final hasLimitedHeight = screenHeight < 550; // Very constrained
```

---

## TESTING CHECKLIST

Before considering any UI work complete:

1. [ ] Test with `isCompact = true` (small phone simulation)
2. [ ] Test with `isTablet = true` (tablet simulation)
3. [ ] Check all Text widgets have overflow handling if user-generated
4. [ ] Verify no hardcoded heights that could cause overflow
5. [ ] Ensure bottom content accounts for safe area padding

---

## EXISTING PATTERNS IN THIS CODEBASE

The app already uses these patterns - follow them:

- `isCompact` boolean for reduced spacing on small screens
- `isTablet` boolean for tablet-specific layouts
- `LayoutBuilder` for responsive constraints
- `SafeArea` with `bottom: false` when custom bottom padding is used
- `MediaQuery.of(context).padding.bottom` for system navigation area

---

## FILE STRUCTURE

- `lib/main_premium.dart` - Main app and home screen (large file)
- `lib/features/` - Feature-specific screens
- `lib/core/services/` - Backend services
- `docs/` - Documentation

---

## COMMON MISTAKES TO AVOID

1. **Don't use Expanded inside SingleChildScrollView** - causes errors
2. **Don't nest ScrollViews** without proper physics handling
3. **Don't assume screen height** - always use LayoutBuilder/MediaQuery
4. **Don't forget keyboard insets** - use `MediaQuery.of(context).viewInsets.bottom`
5. **Don't put unbounded widgets in Column** - ListView, GridView need constraints
