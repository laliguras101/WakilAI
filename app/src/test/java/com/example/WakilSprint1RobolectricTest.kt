package com.example

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.example.ui.auth.WakilAuthEntryScreen
import com.example.ui.auth.WakilSignInContent
import com.example.ui.theme.WakilTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36], qualifiers = "w411dp-h891dp-420dpi")
class WakilSprint1RobolectricTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun testUS01_SplashScreenRendersAndAutoAdvances() {
        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.setContent {
            WakilTheme {
                WakilAuthEntryScreen(
                    onAuthSuccess = {}
                )
            }
        }

        // Verify standalone splash stage renders emblem, title, tagline and version status pill
        composeTestRule.onNodeWithContentDescription("Wakil Legal Scales Emblem").assertIsDisplayed()
        composeTestRule.onNodeWithText("Wakil").assertIsDisplayed()
        composeTestRule.onNodeWithText("Legal Intelligence for Nepal").assertIsDisplayed()
        composeTestRule.onNodeWithText("CONSTITUTION • MULUKI CODES").assertIsDisplayed()

        // Verify disclaimer content is not displayed on splash screen
        composeTestRule.onNodeWithText("AI Legal Information").assertDoesNotExist()

        // Auto-advance after 1500ms delay
        composeTestRule.mainClock.advanceTimeBy(1600L)
        composeTestRule.waitForIdle()

        // Verify transitioned to disclaimer screen
        composeTestRule.onNodeWithText("AI Legal Information").assertExists()
        composeTestRule.onNodeWithTag("disclaimer_continue_button").assertExists()
    }

    @Test
    fun testUS05_PasswordVisibilityToggle() {
        composeTestRule.setContent {
            WakilTheme {
                WakilSignInContent()
            }
        }
        composeTestRule.waitForIdle()

        // 1. Enter password into signin_password_input
        val passwordInput = composeTestRule.onNodeWithTag("signin_password_input")
        passwordInput.assertIsDisplayed().performTextInput("NepalLaw#2026")

        // 2. Initial state: password masked, trailing icon offers 'Show password'
        val toggleButton = composeTestRule.onNodeWithTag("password_visibility_toggle")
        toggleButton.assertIsDisplayed()
        composeTestRule.onNodeWithContentDescription("Show password").assertIsDisplayed()

        // 3. Tap eye toggle: switches to unmasked plain text, toggle offers 'Hide password'
        toggleButton.performClick()
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithContentDescription("Hide password").assertIsDisplayed()

        // 4. Tap eye toggle again: switches back to masked dots, toggle offers 'Show password'
        toggleButton.performClick()
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithContentDescription("Show password").assertIsDisplayed()
    }

    @Test
    fun testSprint1EndToEndJourney() {
        composeTestRule.setContent {
            WakilTheme {
                WakilAppRoot(initialTestGuestMode = false)
            }
        }
        composeTestRule.waitForIdle()

        // 1. Verify Splash & Emblem branding (US-01)
        composeTestRule.onNodeWithText("Wakil").assertIsDisplayed()
        composeTestRule.onNodeWithText("Legal Intelligence for Nepal").assertIsDisplayed()
        composeTestRule.onNodeWithText("CONSTITUTION • MULUKI CODES").assertIsDisplayed()

        // 2. Verify Legal Disclaimer & Accordion (US-02)
        composeTestRule.onNodeWithText("AI Legal Information").assertIsDisplayed()
        composeTestRule.onNodeWithTag("scope_accordion_toggle").assertIsDisplayed().performClick()
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText("Muluki Civil Code 2074", substring = true).assertIsDisplayed()

        // 3. Verify Agreement Checkbox enables Continue button (US-03)
        val continueButton = composeTestRule.onNodeWithTag("disclaimer_continue_button")
        continueButton.assertIsDisplayed().assertIsEnabled()
        composeTestRule.onNodeWithTag("disclaimer_checkbox").performClick()
        composeTestRule.waitForIdle()
        continueButton.assertIsNotEnabled()

        composeTestRule.onNodeWithTag("disclaimer_checkbox").performClick()
        composeTestRule.waitForIdle()
        continueButton.assertIsEnabled().performClick()
        composeTestRule.waitForIdle()

        // 4. Verify Sign In screen & Google Sign In (US-06)
        composeTestRule.onNodeWithText("Sign in to Wakil").assertIsDisplayed()
        composeTestRule.onNodeWithTag("google_sign_in_button").assertIsDisplayed()

        // 5. Verify Skip Auth (Test Mode) (US-07)
        composeTestRule.onNodeWithTag("skip_auth_button").performScrollTo().assertIsDisplayed().performClick()
        composeTestRule.waitForIdle()

        // 6. Verify Authenticated Sprint 1 Workspace Landing
        composeTestRule.onNodeWithText("Namaste").assertIsDisplayed()
        composeTestRule.onNodeWithText("Sprint 1 Deliverables Verified").assertIsDisplayed()

        // 7. Verify Sign Out
        composeTestRule.onNodeWithTag("sprint1_sign_out_button").assertIsDisplayed().performClick()
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText("AI Legal Information").assertIsDisplayed()
    }
}
