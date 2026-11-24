package com.example

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.example.ui.auth.WakilOtpVerificationCard
import com.example.ui.auth.WakilOtpVerificationScreen
import com.example.ui.auth.clearBurnedOtpTokens
import com.example.ui.auth.isOtpTokenBurned
import com.example.ui.auth.verifyPhoneOtp
import com.example.ui.theme.WakilTheme
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36], qualifiers = "w411dp-h891dp-420dpi")
class WakilSprint2RobolectricTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Before
    fun setUp() {
        clearBurnedOtpTokens()
    }

    @Test
    fun testUS09_OtpVerificationCardRendersAllElements() {
        composeTestRule.setContent {
            WakilTheme {
                WakilOtpVerificationCard(
                    phoneNumber = "+977 9841234567"
                )
            }
        }
        composeTestRule.waitForIdle()

        // 1. Verify Card container and destination phone
        composeTestRule.onNodeWithTag("otp_verification_card").assertIsDisplayed()
        composeTestRule.onNodeWithTag("otp_phone_destination").assertIsDisplayed()
        composeTestRule.onNodeWithText("+977 9841234567").assertIsDisplayed()

        // 2. Verify all 6 PIN input boxes exist and are displayed
        for (i in 0..5) {
            composeTestRule.onNodeWithTag("otp_input_box_$i").assertIsDisplayed()
        }

        // 3. Verify actions and initial button states
        composeTestRule.onNodeWithTag("clear_otp_button").assertIsDisplayed()
        composeTestRule.onNodeWithTag("verify_otp_button").assertIsDisplayed().assertIsNotEnabled()
    }

    @Test
    fun testUS09_OtpAutoAdvancementAndVerification() {
        var completedOtp: String? = null
        var verifiedOtp: String? = null

        composeTestRule.setContent {
            WakilTheme {
                WakilOtpVerificationCard(
                    phoneNumber = "+977 9841234567",
                    onOtpComplete = { completedOtp = it },
                    onVerifyClick = { verifiedOtp = it }
                )
            }
        }
        composeTestRule.waitForIdle()

        // Type digits one by one to verify sequential input
        val testDigits = listOf("1", "2", "3", "4", "5", "6")
        for (i in 0..5) {
            composeTestRule.onNodeWithTag("otp_input_box_$i").performTextInput(testDigits[i])
        }
        composeTestRule.waitForIdle()

        // Verify all 6 digits completed callback
        assert(completedOtp == "123456")

        // Verify submit button is now enabled and triggers verify
        val verifyButton = composeTestRule.onNodeWithTag("verify_otp_button")
        verifyButton.assertIsEnabled().performClick()
        composeTestRule.waitForIdle()
        assert(verifiedOtp == "123456")
    }

    @Test
    fun testUS09_OtpPasteFullCode() {
        var completedOtp: String? = null

        composeTestRule.setContent {
            WakilTheme {
                WakilOtpVerificationCard(
                    phoneNumber = "+977 9841234567",
                    onOtpComplete = { completedOtp = it }
                )
            }
        }
        composeTestRule.waitForIdle()

        // Simulate pasting full 6-digit OTP into box 0
        composeTestRule.onNodeWithTag("otp_input_box_0").performTextInput("987654")
        composeTestRule.waitForIdle()

        // Verify distributed across all 6 boxes
        assert(completedOtp == "987654")
        composeTestRule.onNodeWithTag("verify_otp_button").assertIsEnabled()
    }

    @Test
    fun testUS09_ClearCodeActionResetsAllBoxes() {
        var clearClicked = false

        composeTestRule.setContent {
            WakilTheme {
                WakilOtpVerificationCard(
                    phoneNumber = "+977 9841234567",
                    onClearClick = { clearClicked = true }
                )
            }
        }
        composeTestRule.waitForIdle()

        // Type partial code
        composeTestRule.onNodeWithTag("otp_input_box_0").performTextInput("1")
        composeTestRule.onNodeWithTag("otp_input_box_1").performTextInput("2")
        composeTestRule.onNodeWithTag("otp_input_box_2").performTextInput("3")

        // Click Clear Code action
        composeTestRule.onNodeWithTag("clear_otp_button").performClick()
        composeTestRule.waitForIdle()

        assert(clearClicked)
        composeTestRule.onNodeWithTag("verify_otp_button").assertIsNotEnabled()
    }

    @Test
    fun testUS09_ErrorMessageDisplay() {
        composeTestRule.setContent {
            WakilTheme {
                WakilOtpVerificationCard(
                    phoneNumber = "+977 9841234567",
                    errorMessage = "Invalid OTP code. Please check your SMS and try again."
                )
            }
        }
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithTag("otp_error_message").assertIsDisplayed()
        composeTestRule.onNodeWithText("Invalid OTP code. Please check your SMS and try again.").assertIsDisplayed()
    }

    @Test
    fun testUS09_FullOtpVerificationScreenFlow() {
        var successCalled = false
        var backCalled = false

        composeTestRule.setContent {
            WakilTheme {
                WakilOtpVerificationScreen(
                    phoneNumber = "+977 9841234567",
                    onVerificationSuccess = { successCalled = true },
                    onBack = { backCalled = true }
                )
            }
        }
        composeTestRule.waitForIdle()

        // Verify top bar and back button
        composeTestRule.onNodeWithTag("otp_back_button").assertIsDisplayed()

        // Enter valid code
        composeTestRule.onNodeWithTag("otp_input_box_0").performTextInput("123456")
        composeTestRule.waitForIdle()

        // Click verify
        composeTestRule.onNodeWithTag("verify_otp_button").performClick()
        composeTestRule.waitForIdle()

        // Wait for coroutine delay
        composeTestRule.mainClock.advanceTimeBy(500L)
        composeTestRule.waitForIdle()

        assert(successCalled)
    }

    @Test
    fun testUS09_Security3AttemptHardLockout() {
        composeTestRule.setContent {
            WakilTheme {
                WakilOtpVerificationCard(
                    phoneNumber = "+977 9841234567",
                    failedAttempts = 3,
                    maxAttempts = 3,
                    lockoutMinutes = 15
                )
            }
        }
        composeTestRule.waitForIdle()

        // 1. Lockout alert banner is displayed
        composeTestRule.onNodeWithTag("otp_lockout_warning").assertIsDisplayed()
        composeTestRule.onNodeWithText("Account Locked Out").assertIsDisplayed()
        composeTestRule.onNodeWithText("Anti-Brute Force Protection Active").assertIsDisplayed()

        // 2. Verify button is disabled
        composeTestRule.onNodeWithTag("verify_otp_button").assertIsNotEnabled()

        // 3. PIN input boxes are disabled while locked out
        for (i in 0..5) {
            composeTestRule.onNodeWithTag("otp_input_box_$i").assertIsNotEnabled()
        }
    }

    @Test
    fun testUS09_SecuritySingleUseTokenInvalidation() {
        val testPhone = "+977 9811223344"
        val testCode = "456789"
        var firstSuccess = false
        var secondSuccess = false
        var secondErrorMessage: String? = null

        // 1. First verification attempt succeeds
        verifyPhoneOtp(
            phoneNumber = testPhone,
            otpCode = testCode,
            onSuccess = { firstSuccess = true },
            onError = { }
        )
        assert(firstSuccess) { "First verification should succeed" }
        assert(isOtpTokenBurned(testPhone, testCode)) { "Token should be marked as burned" }

        // 2. Second verification attempt with the same token must fail (Replay prevention)
        verifyPhoneOtp(
            phoneNumber = testPhone,
            otpCode = testCode,
            onSuccess = { secondSuccess = true },
            onError = { secondErrorMessage = it }
        )
        assert(!secondSuccess) { "Replayed OTP verification must not succeed" }
        assert(secondErrorMessage != null && secondErrorMessage!!.contains("single-use security policy")) {
            "Replayed OTP should return single-use policy violation error, but got: $secondErrorMessage"
        }
    }
}
