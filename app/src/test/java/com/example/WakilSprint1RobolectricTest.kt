package com.example

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.example.ui.theme.WakilTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class WakilSprint1RobolectricTest {

    @get:Rule
    val composeTestRule = createComposeRule()

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
        continueButton.assertIsDisplayed().assertIsEnabled() // default checked in content
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
