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
    fun testUS04_CredentialInputFieldInteractionsAndValidation() {
        var submittedCredentials: Pair<String, String>? = null
        composeTestRule.setContent {
            WakilTheme {
                WakilSignInContent(
                    onSignInSubmit = { email, pass ->
                        submittedCredentials = Pair(email, pass)
                    }
                )
            }
        }
        composeTestRule.waitForIdle()

        val emailPhoneInput = composeTestRule.onNodeWithTag("signin_email_phone_input")
        val passwordInput = composeTestRule.onNodeWithTag("signin_password_input")
        val submitButton = composeTestRule.onNodeWithTag("signin_submit_button")

        // 1. Initial empty state: submit button disabled
        emailPhoneInput.assertIsDisplayed()
        passwordInput.assertIsDisplayed()
        submitButton.assertIsDisplayed().assertIsNotEnabled()

        // 2. Enter email only: submit button remains disabled
        emailPhoneInput.performTextInput("advocate@wakil.np")
        submitButton.assertIsNotEnabled()

        // 3. Enter password: submit button becomes enabled
        passwordInput.performTextInput("ValidPass123")
        submitButton.assertIsEnabled()

        // 4. Submit form: callback triggered with credentials
        submitButton.performClick()
        assert(submittedCredentials == Pair("advocate@wakil.np", "ValidPass123"))

        // 5. Clear password: button disabled again
        passwordInput.performTextClearance()
        submitButton.assertIsNotEnabled()

        // 6. Test +977 phone input format validation
        emailPhoneInput.performTextClearance()
        emailPhoneInput.performTextInput("+9779841234567")
        passwordInput.performTextInput("SecurePhonePass")
        submitButton.assertIsEnabled()
    }

    @Test
    fun testUS07_SessionPersistenceAndTestModeState() {
        // 1. Verify test guest mode launch
        composeTestRule.setContent {
            WakilTheme {
                WakilAppRoot(initialTestGuestMode = true)
            }
        }
        composeTestRule.waitForIdle()

        // Verify authenticated workspace landing and test guest session
        composeTestRule.onNodeWithText("Namaste").assertIsDisplayed()
        composeTestRule.onNodeWithText("Sprint 1 Deliverables Verified").assertIsDisplayed()
        composeTestRule.onNodeWithText("Guest User (Test Mode)", substring = true).assertIsDisplayed()

        // Sign out returns to unauthenticated state
        composeTestRule.onNodeWithTag("sprint1_sign_out_button").assertIsDisplayed().performClick()
        composeTestRule.mainClock.advanceTimeBy(600L)
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithContentDescription("Wakil Legal Scales Emblem").assertExists()
    }

    @Test
    fun testSprint1EndToEndJourney() {
        composeTestRule.mainClock.autoAdvance = false
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

        // Auto-advance splash after 1500ms
        composeTestRule.mainClock.advanceTimeBy(1600L)
        composeTestRule.waitForIdle()
        composeTestRule.mainClock.autoAdvance = true

        // 2. Verify Legal Disclaimer & Accordion (US-02)
        composeTestRule.onNodeWithText("AI Legal Information").performScrollTo().assertIsDisplayed()
        composeTestRule.onNodeWithTag("scope_accordion_toggle").performScrollTo().assertIsDisplayed().performClick()
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText("Muluki Civil Code 2074", substring = true).performScrollTo().assertIsDisplayed()

        // 3. Verify Agreement Checkbox enables Continue button (US-03)
        val continueButton = composeTestRule.onNodeWithTag("disclaimer_continue_button")
        continueButton.performScrollTo().assertIsDisplayed().assertIsEnabled() // default checked in content
        composeTestRule.onNodeWithTag("disclaimer_checkbox").performScrollTo().performClick()
        composeTestRule.waitForIdle()
        continueButton.assertIsNotEnabled()

        composeTestRule.onNodeWithTag("disclaimer_checkbox").performScrollTo().performClick()
        composeTestRule.waitForIdle()
        continueButton.performScrollTo().assertIsEnabled().performClick()
        composeTestRule.waitForIdle()

        // 4. Verify Sign In screen & Inputs (US-04, US-05, US-06)
        composeTestRule.onNodeWithText("Sign in to Wakil").assertIsDisplayed()
        composeTestRule.onNodeWithTag("signin_email_phone_input").assertIsDisplayed()
        composeTestRule.onNodeWithTag("signin_password_input").assertIsDisplayed()
        composeTestRule.onNodeWithTag("password_visibility_toggle").assertIsDisplayed()
        composeTestRule.onNodeWithTag("google_sign_in_button").assertIsDisplayed()

        // 5. Verify Skip Auth (Test Mode) (US-07)
        composeTestRule.onNodeWithTag("skip_auth_button").performScrollTo().assertIsDisplayed().performClick()
        composeTestRule.waitForIdle()

        // 6. Verify Authenticated Sprint 1 Workspace Landing
        composeTestRule.onNodeWithText("Namaste").assertIsDisplayed()
        composeTestRule.onNodeWithText("Sprint 1 Deliverables Verified").assertIsDisplayed()

        // 7. Verify Sign Out
        composeTestRule.onNodeWithTag("sprint1_sign_out_button").assertIsDisplayed().performClick()
        composeTestRule.mainClock.advanceTimeBy(600L)
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText("Wakil").assertIsDisplayed()
    }
}
