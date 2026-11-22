package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Balance
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.credentials.CredentialManager
import com.example.firebase.configureAppCheck
import com.example.ui.auth.WakilAuthEntryScreen
import com.example.ui.auth.signOutUser
import com.example.ui.theme.WakilSurface
import com.example.ui.theme.WakilTheme
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureAppCheck(this, intent)
        enableEdgeToEdge()
        setContent {
            WakilTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = WakilSurface
                ) {
                    WakilAppRoot()
                }
            }
        }
    }
}

@Composable
fun WakilAppRoot(
    initialTestGuestMode: Boolean = false
) {
    val auth = remember {
        try {
            FirebaseAuth.getInstance()
        } catch (_: Exception) {
            null
        }
    }
    var currentUser by remember { mutableStateOf<FirebaseUser?>(auth?.currentUser) }
    var isTestGuestMode by remember { mutableStateOf(initialTestGuestMode) }

    DisposableEffect(auth) {
        if (auth == null) {
            onDispose { }
        } else {
            val listener = FirebaseAuth.AuthStateListener { firebaseAuth ->
                currentUser = firebaseAuth.currentUser
            }
            auth.addAuthStateListener(listener)
            onDispose {
                auth.removeAuthStateListener(listener)
            }
        }
    }

    if (currentUser == null && !isTestGuestMode) {
        WakilAuthEntryScreen(
            onAuthSuccess = {
                currentUser = auth?.currentUser
            },
            onSkipAuth = {
                isTestGuestMode = true
            }
        )
    } else {
        val context = LocalContext.current
        val scope = rememberCoroutineScope()
        val credentialManager = remember { CredentialManager.create(context) }

        WakilSprint1WorkspaceScreen(
            userEmail = currentUser?.email ?: "Guest User (Test Mode)",
            onSignOut = {
                signOutUser(
                    credentialManager = credentialManager,
                    scope = scope,
                    onSignOutComplete = {
                        isTestGuestMode = false
                        currentUser = null
                    }
                )
            }
        )
    }
}

@Composable
fun WakilSprint1WorkspaceScreen(
    userEmail: String,
    onSignOut: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.surfaceContainerLowest
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth()
            ) {
                Spacer(modifier = Modifier.height(24.dp))

                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Balance,
                        contentDescription = "Emblem",
                        tint = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier.size(40.dp)
                    )
                }

                Spacer(modifier = Modifier.height(20.dp))

                Text(
                    text = "Namaste",
                    style = MaterialTheme.typography.displayMedium,
                    color = MaterialTheme.colorScheme.onSurface
                )

                Text(
                    text = "Welcome to Wakil Legal Workspace",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.secondary
                )

                Spacer(modifier = Modifier.height(16.dp))

                Surface(
                    color = MaterialTheme.colorScheme.surfaceContainerLow,
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = "Authentication Active",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Text(
                            text = "Signed in as: $userEmail",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                Surface(
                    color = MaterialTheme.colorScheme.surfaceContainerLowest,
                    shape = RoundedCornerShape(16.dp),
                    border = CardDefaults.outlinedCardBorder(),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Text(
                            text = "Sprint 1 Deliverables Verified",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold
                        )
                        val deliverables = listOf(
                            "US-01: Splash Screen & Emblem Branding",
                            "US-02: Bilingual Mandatory Legal Disclaimer",
                            "US-03: Agreement Checkbox & Consent",
                            "US-04: Credential Authentication Form",
                            "US-05: Password Visibility Eye Toggle",
                            "US-06: Google OAuth One-Tap Sign-In",
                            "US-07: Remember Device Persistence & Skip Auth"
                        )
                        for (item in deliverables) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(16.dp)
                                )
                                Text(
                                    text = item,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }
            }

            Button(
                onClick = onSignOut,
                shape = CircleShape,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                    contentColor = MaterialTheme.colorScheme.onSurface
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp)
                    .testTag("sprint1_sign_out_button")
            ) {
                Icon(
                    imageVector = Icons.Default.ExitToApp,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Sign Out")
            }
        }
    }
}
