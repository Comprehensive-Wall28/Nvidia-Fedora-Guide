# NVIDIA on Fedora desktops

This guide will help you to install the proprietary NVIDIA drivers replacing the open source Nouveau drivers for both Fedora Workstation (Gnome, KDE and Cosmic spins) and Atomic desktops (Silverblue, Kinoite and Sway).


## What you need to know

The hardest part is getting the drivers to load with Secure Boot. Secure Boot blocks the driver's modules from loading unless we sign them.

Run the following command in the terminal to check Secure Boot status:

```bash
mokutil --sb-state
```

If enabled, you will need to follow some extra (but simple) steps. Don't disable Secure Boot if it was already enabled to improve your security.

All you need to do is follow the guide and *hopefully* everything works smoothly! 

Please check if your Desktop Environment is compatible with the Nvidia drivers since there are more steps needed for some that may not be listed here. This is not a problem for KDE and Gnome but may be a problem for some of the spins. If you find any, please create an issue with the details.

You will mostly need to just copy and paste commands into the terminal. But, make sure to read everything carefully!

If you find any mistake or want to add some missing information, create a pull request with the changes or just create an issue. All help is appreciated!

Consult the official documentation (Sources listed below) if more information is needed.


## Identify your system

This guide is made STRICTLY for Fedora Workstation and all it's spins (KDE and Cosmic) and Fedora Atomic (Silverblue, Kinoite and Sway).

* **Sway Users**
For users of Sway and Sway Atomic (Sericea), you will need to open `/etc/sway/environment` and uncomment or add the following two lines:

```env
SWAY_EXTRA_ARGS="$SWAY_EXTRA_ARGS --unsupported-gpu"
WLR_NO_HARDWARE_CURSORS=1
```

Please scroll down to the relevant section related to your Fedora installation or choose from table of contents:

## Table of Contents

1.  [Fedora Workstation & KDE (with spins)](#installing-nvidia-drivers-on-fedora-workstation-and-its-spins)

2.  [Fedora Atomic (Silverblue, Kinoite and Sway)](#installing-nvidia-drivers-on-fedora-atomic)
   
3.  [Common Problems](#common-problems)

4.  [Sources](#sources)
---

# Installing NVIDIA drivers on Fedora Workstation and it's spins

## 0. Before we get started!

If you have Secure Boot disabled, Skip step 2.
Otherwise, it's still easy to get the drivers with Secure Boot. 

## 1. Preparation

* **Update your system:** Ensure your installation is up-to-date:

```bash
sudo dnf update
```

* **Enable RPM Fusion:** This provides access to the NVIDIA drivers.

```bash
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
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

You will need to identify your GPU to choose which drivers to install. Run this command to find your GPU:

```bash
/sbin/lspci | grep -e VGA
```
Accordingly, choose which driver to download below:

## For NVIDIA GPUs from 2014 or higher (Current GeForce, Quadro and Tesla):

```bash
sudo dnf install akmod-nvidia
sudo dnf install xorg-x11-drv-nvidia-cuda #for cuda and nvidia-smi
```

## For legacy GeForce 600/700 series (Kepler):

```bash
sudo dnf install xorg-x11-drv-nvidia-470xx akmod-nvidia-470xx
sudo dnf install xorg-x11-drv-nvidia-470xx-cuda #cuda support
```
Additionally, for this driver (Geforce 600/700 series ONLY!) you need to install X11 session if you are on Gnome or KDE:

Gnome:
```bash
sudo dnf install gnome-session-xsession xorg-x11-drivers xorg-x11-xinit
```
KDE:
```bash
sudo dnf install plasma-workspace-x11 xorg-x11-drivers xorg-x11-xinit
```
After the final reboot, Make sure to use the X11 session (found bottom right when logging in)

## Final step

Now that we installed the driver, confirm that it's built or not by running:

```bash
modinfo -F version nvidia
```
In the output you should see the driver version number. If you see an error then it's still being built. Wait for a minute and retry running the command.

When the output is correct then you are finally done with the installation! Reboot your system.

If you see "Nvidia modules failed to load" on startup, then the secure boot step was unsuccessful.

After booting, run the following in the terminal to check your GPU's status:

```bash
nvidia-smi
```
NOTE: If it failed then you didn't install Nvidia Cuda from the steps above.


//------------------------------------------------------------------------------------------//


# Installing NVIDIA Drivers on Fedora Atomic

## 0. Before we get started!

Due to Fedora Atomic's immutable nature, we will need to use a "trick" to get the drivers correctly working with Secure Boot. 
Thanks to CheariX for providing the fix to everyone: https://github.com/CheariX/silverblue-akmods-keys

With Atomic, you can revert easily if anything gets messed up! Please check the official Fedora documentation to learn how you can do so: 
https://docs.fedoraproject.org/en-US/fedora-silverblue/updates-upgrades-rollbacks/

Sway users need to perform two extra steps, one is listed in "Identify your system" above and the other is below when adding the kernel arguments. [Notes provided by shdwpunk].

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

## 2. Set up the Secure Boot key (Secure Boot enabled only!)

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
git clone https://github.com/CheariX/silverblue-akmods-keys
cd silverblue-akmods-keys
```

* **Build and install:**

```bash
sudo bash setup.sh
sudo rpm-ostree install akmods-keys-*.rpm
```

## 4. Install NVIDIA Drivers (For current GeForce, Tesla and Quadro GPUs)

Install the driver and Cuda. Last command will blacklist the Nouveau driver and nova_core. For Sway users, You will need to also add an additional kernel arg listed below: 

* **Install the Nvidia driver with Cuda for Kinoite and Silverblue**

```bash
sudo rpm-ostree install akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda
sudo rpm-ostree kargs --append=rd.driver.blacklist=nouveau,nova_core --append=modprobe.blacklist=nouveau,nova_core --append=nvidia-drm.modeset=1 
```

* **Install the Nvidia driver with Cuda for Sway Atomic**

```bash
sudo rpm-ostree install akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda
sudo rpm-ostree kargs --append=rd.driver.blacklist=nouveau,nova_core --append=modprobe.blacklist=nouveau,nova_core --append=nvidia-drm.modeset=1 --append=initcall_blacklist=simpledrm_platform_driver_init
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

## Final step

Now that we installed the driver, confirm that it's built by running:

```bash
modinfo -F version nvidia
```
In the output you should see the driver version number.

If you see "Nvidia modules failed to load" on startup, then the secure boot step was unsuccessful.

After booting, run the following in the terminal to check your GPU's status:

```bash
nvidia-smi
```
NOTE: If it failed then you didn't install Nvidia Cuda from the steps above.

## Important Note (Atomic)

Enabling the RPM fusion repo alone will enable it in a "fixed" state. Meaning after a major Fedora update (42 -> 43) The repos won't be updated!

To optionally (recommended) "unlock", Run the following command:

```bash
sudo rpm-ostree update \
    --uninstall rpmfusion-free-release \
    --uninstall rpmfusion-nonfree-release \
    --install rpmfusion-free-release \
    --install rpmfusion-nonfree-release
```

After that, reboot!

```bash
reboot
```

For more information about this, check the official documentation: https://docs.fedoraproject.org/en-US/fedora-silverblue/tips-and-tricks/#_enabling_rpm_fusion_repos

# Common Problems

## Nvidia modules failed to load (on startup)

If you got this message after installation, The secure boot enrollment was not done properly. Please retry the Secureboot steps mentioned for your Fedora installation. 
No need to reinstall the drivers themselves!

## Black screen after booting up

This means the installed drivers were the incorrect version for your GPU (Was kepler but installed Geforce instead and vice versa)
If that happens, boot into TTY (reboot and spam CTRL+ALT+F2) and remove the Nvidia packages manually

For workstation and it's spins:

```bash
sudo dnf remove "*nvidia*" "*akmod-nvidia*" "*xorg-x11-drv-nvidia*"

sudo dracut -f --regenerate-all
```

For Atomic desktops:

```bash
rpm-ostree override reset "*nvidia*"
```

## For Atomic users who updated to kernel 6.15 and had the drivers fail

If you installed the drivers and updated to 6.15, you need to add "nova_core" to the blacklist alongside nouveau. 
Ignore this if it's working properly since it's only for those who followed the steps before I added 
nova_core to the commands. If you ran the older command run:

```bash
sudo rpm-ostree kargs --append=rd.driver.blacklist=nouveau,nova_core --append=modprobe.blacklist=nouveau,nova_core
```
This should fix the issue with the drivers.

# Contributers

* shdwpunk

# Sources
Configuring RPMFusion:
* https://rpmfusion.org/Configuration
  
RPMFusion Nvidia Documentation:
* https://rpmfusion.org/Howto/NVIDIA

RPMFusion Secureboot Documentation:
* https://rpmfusion.org/Howto/Secure%20Boot

Nvidia drivers for Sway Atomic
* https://docs.fedoraproject.org/en-US/fedora-sericea/troubleshooting/#_using_nvidia_drivers




