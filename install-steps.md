# Steps to install

## 1/ Install Ubuntu as per normal

Just follow a standard Ubuntu installation with the variant of your choice. Recommendations are:

* Lubuntu (i386/i686/"32-bit" variant) - very lightweight Linux operating system for reviving old machines
* Ubuntu MATE - another lightweight Ubuntu variant, for a classic desktop experience that's easy to use
* Ubuntu - the standard distribution with the Unity interface

## 2/ Install Our-PXE and its tools

You need to be connected to the Internet for the next steps.

Once booted into the freshly installed system, some initial technical preparation needs to be done to install the easy-install tools.

Open a browser and download the following: [link to easy-installer]

Save the file to your Downloads folder.

Open a terminal by using the keyboard shortcut [Ctrl + Alt + T] and then type the following lines, presing the Return key for each new line:

	cd Downloads
	tar xf partimus.tar
	./partimus-setup.sh

Some messages will fly by on the screen.

At this point you can close the terminal.

You can now customize the system's look and feel, and install any application syou want for the final system.

The following instructions work for Lubuntu - adapt to your chosen system as needed:

* To change the desktop background, right-click on the desktop and choose "Desktop preferences"
* To change other appearances of the system
	* go to the Start menu in the bottom left of the screen
	* choose the Preferences menu
	* Choose an item from that menu to customize
* To install software
	* Go to the Start menu in the bottom left of the screen
	* choose the System Tools
	* Choose the "Lubuntu Software Centre"

Note: if you want to set your own desktop background that every user in the new system will have when they first are created,
	* download the wallpaper picture you want;
	* save the picture to : File System (choose this in the list on the left): partimus
	* then customize your desktop background to use that same file.

[insert screenshots]

## 3/ Create the custom installation CD

On your desktop there is a program called "Make Partimus CD" - open it to launch the creation process. [this will look like nothing is happening; open a terminal and run `tail -f /root/respin.log` to see what's happening]

When the CD is ready, you will see a window open where the CD's .ISO file has been created.

[note - need to add log monitoring task application...]

You will also see the respin.log report on your desktop.

You can now burn this ISO file to a writable DVD using the Brasero application.