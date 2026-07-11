# Forge

`forge` is a Swift CLI for generating SwiftUI feature templates inside Xcode projects.
It can generate standalone presentation architectures and Clean Architecture features paired with different presentation styles.

Current command:

```sh
forge make Login
forge make Login --path /path/to/MyApp
forge make Login -mvvm
forge make Login -mvvm -clean
forge make Login -viper -clean
forge make Login -tca
```

Install locally:

```sh
make install
```

By default this installs the release binary to `/usr/local/bin/forge`.
You can choose another install directory with:

```sh
make install INSTALL_DIR="$HOME/.local/bin"
```

Default `clean-mvvm` structure (used when no architecture flag is provided, or with `-mvvm -clean`):

```text
Login/
  LoginDependencyContainer.swift
  Presentation/
    LoginView.swift
    LoginViewModel.swift
  Domain/
    LoginEntity.swift
    LoginUseCase.swift
    LoginRepository.swift
  Data/
    LoginRepositoryImpl.swift
    LoginRemoteDataSource.swift
    LoginModels.swift
```

Standalone `mvvm` structure:

```text
Login/
  LoginDependencyContainer.swift
  Presentation/
    LoginView.swift
    LoginViewModel.swift
```

Standalone `mvi` structure:

```text
Login/
  LoginDependencyContainer.swift
  Presentation/
    LoginView.swift
    LoginStore.swift
    LoginState.swift
    LoginIntent.swift
    LoginReducer.swift
```

Standalone `viper` structure:

```text
Login/
  LoginDependencyContainer.swift
  Presentation/
    LoginView.swift
    LoginPresenter.swift
    LoginInteractor.swift
    LoginRouter.swift
    LoginEntity.swift
    LoginContracts.swift
```

Standalone `vip` structure:

```text
Login/
  LoginDependencyContainer.swift
  Presentation/
    LoginView.swift
    LoginInteractor.swift
    LoginPresenter.swift
    LoginWorker.swift
    LoginModels.swift
```

Standalone `mvp` structure:

```text
Login/
  LoginDependencyContainer.swift
  Presentation/
    LoginView.swift
    LoginPresenter.swift
    LoginModel.swift
```

Standalone `tca` structure:

```text
Login/
  Presentation/
    LoginFeature.swift
    LoginView.swift
```

Clean variants add `Domain/` and `Data/` to the selected presentation style:

```text
Login/
  LoginDependencyContainer.swift
  Presentation/
    ...selected presentation files...
  Domain/
    LoginEntity.swift
    LoginUseCase.swift
    LoginRepository.swift
  Data/
    LoginRepositoryImpl.swift
    LoginRemoteDataSource.swift
    LoginModels.swift
```

Each generated Swift file includes an Xcode-style header with the file name,
detected project name, local author name, and creation date.

Architecture options:

Pick one architecture flag: `-mvvm`, `-mvi`, `-viper`, `-vip`, `-mvp`, `-tca`.

Add `-clean` to include Domain and Data layers. Without `-clean`, only the presentation layer is generated.

```sh
# Default — Clean Architecture + MVVM
forge make Login
forge make Login -mvvm -clean

# Standalone presentation types
forge make Login -mvvm
forge make Login -mvi
forge make Login -viper
forge make Login -vip
forge make Login -mvp
forge make Login -tca

# Clean Architecture + presentation types
forge make Login -mvvm -clean
forge make Login -mvi -clean
forge make Login -viper -clean
forge make Login -vip -clean
forge make Login -mvp -clean
forge make Login -tca -clean
```

The first version creates files and detects a `.xcodeproj` in the target directory. Automatic Xcode project registration is the next implementation step.
