
# Nvidia on Fedora desktops

## Beginner notes:

The reason I created this guide is the fragmentation of steps in official documentation on RPM Fusion. 

## What you need to know

The hardest part for many is getting the drivers to load with Secure Boot. Secure Boot blocks Nvidia driver's modules from loading unless we sign them.

Please, run the following command in the terminal to determine if you have Secure Boot enabled:

```bash
mokutil --sb-state
```
This will slightly complicate it for you if enabled (which, it should be). However, if it is disabled you will skip the steps for secureboot making it much easier. 

All you need to do is follow the guide and *hopefully* everything works smoothly! 

You will mostly need to just copy and paste commands into the terminal. But, make sure to read everything carefully!

If you find any mistake or want to add some missing information, create a pull request with the changes or just create an issue. All help is appreciated!

## Determine your system

This guide is made STRICTILY for Fedora Workstation and all it's spins (KDE and etc). Fedora Atomic (Silverblue, Kinoite and etc).

Please scroll down the the relevant section related to your Fedora installation.


# Installing NVIDIA Drivers on Fedora Atomic

## 0. Before we get started!

Due to Fedora Atomic's immutable nature, we will need to use a "trick" to get the drivers correctly working with SecureBoot. 
Thanks to CheariX for providing the fix to everyone: https://github.com/CheariX/silverblue-akmods-keys

Additionally, installed packages will be layered on your installation. While completely supported, this *might* cause issues when upgrading Fedora versions (ex: from Fedora 41 to 42) 

The beauty of Atomic is that you can easily revert if anything gets messed up! Please check the official Fedora documentation to see how you can do so if anything gets messed up: 
https://docs.fedoraproject.org/en-US/fedora-silverblue/updates-upgrades-rollbacks/

## 1. Preparation

* **Update your system:** Ensure your Silverblue installation is up-to-date:

```bash
sudo rpm-ostree update
```

* **Install necessary packages:**

```bash
sudo rpm-ostree install rpmdevtools akmods
```

* **Enable RPM Fusion:** This provides access to the NVIDIA drivers.

```bash
sudo rpm-ostree install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

* **Reboot:** Reboot to apply the RPM Fusion changes.

```bash
systemctl reboot
```

## 2. Set up Secure Boot (Secure Boot enabled only!)

* **Generate a Machine Owner Key (MOK):**

```bash
sudo kmodgenca
```

* **Import the key:**

```bash
sudo mokutil --import /etc/pki/akmods/certs/public_key.der
```

*   You'll be prompted to set a password during this process; remember it! You'll need it after rebooting.

## 3. Install `akmods-keys` (Secure Boot enabled only!)

* **Clone the repository:**

```bash
git clone [https://github.com/CheariX/silverblue-akmods-keys](https://github.com/CheariX/silverblue-akmods-keys)
cd silverblue-akmods-keys
```

* **Build and install:**

```bash
sudo bash setup.sh
sudo rpm-ostree install akmods-keys-*.rpm
```

## 4. Install NVIDIA Drivers

* **Install the `akmod` package:**

```bash
sudo rpm-ostree install akmod-nvidia xorg-x11-drv-nvidia
```

* **Install CUDA (This gives you access to "nvidia-smi" which will be useful):**

```bash
sudo rpm-ostree install akmod-nvidia xorg-x11-drv-nvidia-cuda
```

* **Blacklist Nouveau:** This prevents conflicts with the NVIDIA driver and Nouveau driver.

```bash
sudo rpm-ostree kargs --append=rd.driver.blacklist=nouveau --append=modprobe.blacklist=nouveau --append=nvidia-drm.modeset=1
```

## 5. Reboot and Enroll the Key. (Key enrollment will happen for Secure Boot enabled only!!)

* **Reboot:**
For Secure Boot enabled. Otherwise, you will not see a MOK enrollment screen and you only need to restart!

On the next boot MOK Management is launched and you have to choose "Enroll MOK"

Choose "Continue" to enroll the key.

Confirm enrollment by selecting "Yes".

You will need to enter the password you created earlier.

```bash
systemctl reboot
```

## Important Notes:

TBA
