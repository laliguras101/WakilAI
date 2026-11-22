package com.example.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val WakilLightColorScheme = lightColorScheme(
    primary = WakilPrimary,
    onPrimary = WakilOnPrimary,
    primaryContainer = WakilPrimaryContainer,
    onPrimaryContainer = WakilOnPrimaryContainer,
    secondary = WakilSecondary,
    onSecondary = WakilOnSecondary,
    secondaryContainer = WakilSecondaryContainer,
    onSecondaryContainer = WakilOnSecondaryContainer,
    tertiary = WakilTertiary,
    onTertiary = WakilOnTertiary,
    tertiaryContainer = WakilTertiaryContainer,
    onTertiaryContainer = WakilOnTertiaryContainer,
    background = WakilBackground,
    onBackground = WakilOnBackground,
    surface = WakilSurface,
    onSurface = WakilOnSurface,
    surfaceVariant = WakilSurfaceVariant,
    onSurfaceVariant = WakilOnSurfaceVariant,
    surfaceContainerLowest = WakilSurfaceContainerLowest,
    surfaceContainerLow = WakilSurfaceContainerLow,
    surfaceContainer = WakilSurfaceContainer,
    surfaceContainerHigh = WakilSurfaceContainerHigh,
    surfaceContainerHighest = WakilSurfaceContainerHighest,
    outline = WakilOutline,
    outlineVariant = WakilOutlineVariant,
    error = WakilError,
    onError = WakilOnError,
    errorContainer = WakilErrorContainer,
    onErrorContainer = WakilOnErrorContainer,
    inverseSurface = WakilInverseSurface,
    inverseOnSurface = WakilInverseOnSurface,
    inversePrimary = WakilInversePrimary
)

@Composable
fun MyApplicationTheme(
    darkTheme: Boolean = false,
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = WakilLightColorScheme,
        typography = Typography,
        content = content
    )
}

@Composable
fun WakilTheme(
    content: @Composable () -> Unit
) {
    MyApplicationTheme(content = content)
}
