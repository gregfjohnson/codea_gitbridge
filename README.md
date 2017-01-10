# GitBridge:  A tool for moving code between Codea and git working directories #

## Introduction ##

GitBridge is yet another approach to copying files to and from Codea.

This project allows you to move code back and forth between Codea on your
iPad, and a git working directory (or optionally a standard vanilla directory)
on another computer.

The intended use of GitBridge is that you have a standard home development
machine, which is set up "just right" for your programming happiness
and convenience.  (This early-release version of GitBridge was developed
on and for Linux machines.)

You set your up your iPad next to this machine, and fire up Codea.
Whenever you feel like it, you move files from Codea to your other
computer, or from the other computer to Codea, with a single button-click.

You can go back and forth between working with your normal code editor and
programming environment, and working with the embedded code editor
that comes with Codea.

GitBridge has a little pure-lua server that you run on your development
machine, and the GitBridge Codea project communicates with that server
over TCP.

The server uses os.execute() to run git commands automatically, so
that all of your work is archived.

The server listens to a command-line specified TCP port.

On the development machine, the server creates a flat list of
directories for each of the Codea projects, and each of these directories
contains a file per tab in the corresponding Codea project.

## Installation and Setup ##

GitBridge was developed and tested on a Linux box.  The port to Windows
and other platforms is not complete as of GitBridge version 0.1.1.

You need to have git installed, unless you run `--no-git`.

Download gitbridge from github:
~~~
  git clone http://github.com/gregfjohnson/codea_gitbridge
  cd codea_gitbridge

  # If you don't want to execute right out of this download
  # directory, copy the server to some handy place on your
  # development box:

  sudo cp git_bridge.lua util.lua /usr/local/bin
~~~

On your development machine, create a directory and initialize it
for git:

~~~
  mkdir /home/fred/my_codea_projects
  git init /home/fred/my_codea_projects
~~~
Start the server.  (You must ensure that the specified TCP port is
accessible through firewalls etc.)
~~~
  git_bridge.lua -P 10000 -r /home/fred/my_codea_projects
~~~
That's it for the server side.

Here is the complete list of command line options for the server:
~~~
git_bridge.lua -h
Options:
     -h         Help message
     --test     Test mode; do not write files
     --no-git   Disable git operations; just copy files
     -P N       Port for connection
     -r dir     Root directory to use for sending and receiving files
~~~

On the Codea side, you will need to create a new project:

1.  Create a new project named GitBridge
2.  In the GitBridge project, create three new tabs with empty files:
   * Util
   * Receivefile
   * Sendfile
3.  Copy the four files in codea_gitbridge/GitBridge into Codea.

I would suggest you start Air Code option on Codea, and use your browser.

In your browser, go to to the URL indicated by Codea.  Then, open the
GitBridge project you just created.  Copy and Paste the three support
files first:  Util, Receivefile, and Sendfile.

Finally, replace the default contents of Main with the contents of
GitBridge/Main.

You might need to hit the "Restart" icon on Codea after that final
copy/paste to the Main tab.

## Usage ##

### Using GitBridge inside Codea ###

When you run GitBridge, you will see a simple, minimal set of Codea
parameters.  Edit the host_port parameter with the IP address of your
development machine.  (You need the actual IP address, not a machine
name.)  Add the port number you used to start git_bridge.lua.

Then, enter the names of Codea projects.

The "Copy_projects_now" boolean button will tell GitBridge to send
all of the tabs for your selected projects over to your server.

You can edit the files on your server, and then copy them back over
to Codea.  This is done by moving "Send_or_Receive" to the right
(receive) position, and then selecting "Copy_projects_now".

You can add GitBridge to existing projects.  To do that, add
GitBridge as a dependency to an existing project.  Then, add
the following two lines:
~~~
function setup()
    GitBridge_setup()

    -- the rest of your own setup function for this project
    -- ..
end

function draw()
    GitBridge_draw()

    -- the rest of your own draw function for this project
    -- ..
end
~~~

This adds the GitBranch GUI parameters to your project.  You can then
copy files to and from this project from right inside the project.

### What happens in the git working directory ###

Files that you send will be committed on the git "master" branch.

Codea files that would be overwritten during receive operations are
committed to a git branch named "codea_backup".

git_branch.lua creates automatically generated commit messages, and
mindlessly commits everything it receives.  If you plan to do a `git push`
from your local GitBridge working directory to a remote or shared
git repository , you will likely want to do a `git rebase`
operation first.

(Version 2.0 of GitBridge will incorporate artificial intelligence,
so that it can create witty and insightful commit messages for
you automatically.)

## Dependencies ##

You will need a linux or unix box for the server side.

GitBridge uses the lua `socket` module.  You will need `socket` on your
development machine.  `socket` can be installed via luarocks.

## History ##

This project was inspired by https://github.com/loopspace/backupCodea.

The main difference is that backupCodea is (elegantly) symmetrical,
whereas GitBridge has more of a client/server design.  With GitBridge,
the server-side component runs continuously, and the Codea side is a
one-shot operation that interacts with the server.
