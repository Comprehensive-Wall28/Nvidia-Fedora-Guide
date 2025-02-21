
# Nvidia on Fedora desktops

The reason I created this guide is the fragmentation of steps in official documentation on RPM Fusion. Hopefully, This will help you to get Nvidia working.


## What you need to know

The hardest part for many is getting the drivers to load with Secure Boot. Secure Boot blocks Nvidia driver's modules from loading unless we sign them.

Please, run the following command in the terminal to determine if you have Secure Boot enabled:

```bash
mokutil --sb-state
```

This will slightly complicate it for you if enabled (which, it should be). However, if it is disabled you will skip the steps for secureboot making it much easier. Don't disable Secure Boot if it was already enabled! 

All you need to do is follow the guide and *hopefully* everything works smoothly! 

You will mostly need to just copy and paste commands into the terminal. But, make sure to read everything carefully!

If you find any mistake or want to add some missing information, create a pull request with the changes or just create an issue. All help is appreciated!


## Determine your system

This guide is made STRICTILY for Fedora Workstation and all it's spins (KDE and etc). Fedora Atomic (Silverblue, Kinoite and etc).

Please scroll down the the relevant section related to your Fedora installation.

# Fedora Workstation and it's spins

## 0. Before we get started!

If you have Secure Boot disabled, Skip to step 3

Otherwise, it's still easy to get the drivers with Secure Boot. 

## 1. Preparation

* **Update your system:** Ensure your Silverblue installation is up-to-date:

```bash
sudo dnf update
```

## 2. Secure Boot key enrollment

* **Install these packages:**

```bash
sudo dnf install kmodtool akmods mokutil openssl
```

* **Generate a default key:**

```bash
sudo kmodgenca -a
```

* **Enroll the key in MOK:**

After running the command, you will be asked for a password. Create a short password (ex: 0000) and remember it for a later step!

```bash
sudo mokutil --import /etc/pki/akmods/certs/public_key.der
```

* **Reboot to enroll:**

On the next boot MOK Management is launched and you have to choose "Enroll MOK" (MOK management is a blue screen on startup)

Choose "Continue" to enroll the key.

Enroll by selecting "Yes".

You will need to enter the password you created earlier.

```bash
systemctl reboot
```

## 3. Installing the drivers

You will need to identify your GPU to choose which drivers to install. 

## For 2014 or higher NVIDIA gpus (Current GeForce, Quadro and Tesla):

```bash
sudo dnf install akmod-nvidia
sudo dnf install xorg-x11-drv-nvidia-cuda #for cuda and nvidia-smi
```

## For legacy GeForce 600/700 series (Kepler):

```bash
sudo dnf install xorg-x11-drv-nvidia-470xx akmod-nvidia-470xx
sudo dnf install xorg-x11-drv-nvidia-470xx-cuda #cuda support
```
If you are uncertain on which to choose, check your driver model with the following command:

```bash
/sbin/lspci | grep -e VGA
```

## Final step

Now that we installed the driver, confirm that they are built by running:

```bash
modinfo -F version nvidia
```
In the output you should see the driver version number. If you see an error then it's still being built. Wait for a minute and retry running the command

When the output is correct then you are finally done with the installation! Reboot your system.

If you see "Nvidia modules failed to load" on startup, then the secure boot step was unsuccessful.

After booting, run the following in the terminal to check your GPU's status:

```bash
nvidia-smi
```
NOTE: If it failed then you didn't install Nvidia Cuda from the steps above.




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

## 4. Install NVIDIA Drivers (For current GeForce, Tesla and Quadro GPUs)

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
