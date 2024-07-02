# Android Setup

After you've completed the [Rust setup](docs/getting-started/rust-setup.md) you should be able to run `cargo run --bin android`. This will create a new folder called `MoproAndroidBindings`. It should look like the structure

```sh
MoproAndroidBindings
├── jniLibs
│   ├── arm64-v8a
│   │   └── libuniffi_mopro.so
│   ├── armeabi-v7a
│   │   └── libuniffi_mopro.so
│   ├── x86
│   │   └── libuniffi_mopro.so
│   └── x86_64
│       └── libuniffi_mopro.so
└── uniffi
    └── mopro
        └── mopro.kt
```

First we will create an android app through Android Studio. If you already have an app project, you can skip this step. We'll do File -> New -> New Project and create an Empty Activity.

![create an android app project](/img/android-example-1.png)

Your android project should be opened now.

Then add jna to `app/build.gradle.kts`

```kts
dependencies {
   ...
   implementation("net.java.dev.jna:jna:5.13.0@aar")
   ...
}
```

![add jna dependency](/img/android-example-2.png)

Sync gradle with `shift`+`cmd`+`O`, or press

![android sync gradle](/img/android-example-4.png)

Open Finder and drag folders:

1. Move the `MoproAndroidBindings/jniLibs/` folder into `app/src/main/jniLibs/`.
2. Move the `MoproAndroidBindings/uniffi/mopro/mopro.kts` file into `app/src/main/java/uniffi/mopro/mopro.kt`

![android bindings](/img/android-bindings.png)

Create an asset folder: File -> New -> Folder -> Assets Folder. <br/>
Paste the zkey in the assets folder.

![android paste zkey](/img/android-example-3.png)

## Proving from the app

In your project, there should be a file named `MainActivity.kt`

> It should be under `app/src/main/java/com/example/YOUR_APP/MainActivity.kt`

Import the following functions:

```kotlin
import android.content.Context
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.unit.dp
import androidx.compose.material3.Button
import kotlinx.coroutines.launch
import uniffi.mopro.generateCircomProof
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
```

This will make the proving functions `generateCircomProof` available in this module and also help to load zkey.

In the `MainActivity.kt`, replace the `Greeting("Android")` with

```kotlin
MainScreen(this)
```

Add a private function to load zkey. It is used to copy a file from the app's assets directory to the app's internal storage so that we can read the path of the zkey file.

<!--TODO: Improve loading zkey-->

```kotlin
private fun copyAssetToInternalStorage(context: Context, assetFileName: String): String? {
    val file = File(context.filesDir, assetFileName)
    return try {
        context.assets.open(assetFileName).use { inputStream ->
            FileOutputStream(file).use { outputStream ->
                val buffer = ByteArray(1024)
                var length: Int
                while (inputStream.read(buffer).also { length = it } > 0) {
                    outputStream.write(buffer, 0, length)
                }
                outputStream.flush()
            }
        }
        file.absolutePath
    } catch (e: IOException) {
        e.printStackTrace()
        null
    }
}
```

At the bottom of this file we'll create a view with a function to generate a proof. In this example we're going to prove a simple circuit that accepts two inputs named `a` and `b` and generates an output `c`.

```kotlin
@Composable
fun MainScreen(context: Context) {
    val coroutineScope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Button(onClick = {
            coroutineScope.launch {
                val assetFilePath = copyAssetToInternalStorage(context, "multiplier2_final.zkey")
                assetFilePath?.let { path ->
                    val inputs = mutableMapOf<String, List<String>>()
                    inputs["a"] = listOf("3")
                    inputs["b"] = listOf("5")
                    val res = generateCircomProof(path, inputs)
                    println(res)
                }
            }
        }) {
            Text(text = "Generate Proof")
        }
    }
}
```

<details>
  <summary>Full `MainActivity.ts` (simplified)</summary>

```kotlin
package com.example.moproandroidapp

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.moproandroidapp.ui.theme.MoproAndroidAppTheme
import kotlinx.coroutines.launch
import uniffi.mopro.generateCircomProof
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
      super.onCreate(savedInstanceState)
      setContent {
          MoproAndroidAppTheme {
              // A surface container using the 'background' color from the theme
              Surface(
                  modifier = Modifier.fillMaxSize(),
                  color = MaterialTheme.colorScheme.background
              ) {
                  MainScreen(this)
              }
          }
      }
  }
}

@Composable
fun MainScreen(context: Context) {
  val coroutineScope = rememberCoroutineScope()

  Column(
      modifier = Modifier
          .fillMaxSize()
          .padding(16.dp)
  ) {
      Button(onClick = {
          coroutineScope.launch {
              val assetFilePath = copyAssetToInternalStorage(context, "multiplier2_final.zkey")
              assetFilePath?.let { path ->
                  val inputs = mutableMapOf<String, List<String>>()
                  inputs["a"] = listOf("3")
                  inputs["b"] = listOf("5")
                  val res = generateCircomProof(path, inputs)
                  println(res)
              }
          }
      }) {
          Text(text = "Generate Proof")
      }
  }
}

private fun copyAssetToInternalStorage(context: Context, assetFileName: String): String? {
  val file = File(context.filesDir, assetFileName)
  return try {
      context.assets.open(assetFileName).use { inputStream ->
          FileOutputStream(file).use { outputStream ->
              val buffer = ByteArray(1024)
              var length: Int
              while (inputStream.read(buffer).also { length = it } > 0) {
                  outputStream.write(buffer, 0, length)
              }
              outputStream.flush()
          }
      }
      file.absolutePath
  } catch (e: IOException) {
      e.printStackTrace()
      null
  }
}

```

</details>

You should now be able to run the Android app (`^`+`R` or `ctrl`+`R`) on the simulator or a device and build a proof. The app should log the proof.
