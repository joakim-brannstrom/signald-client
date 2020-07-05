# signald-client

**signald-client** is a library to interact with
[signald](https://git.callpipe.com/finn/signald).

# Getting Started

signald-client depends on the following software packages:

 * [D compiler](https://dlang.org/download.html) (dmd 2.079+, ldc 1.11.0+)

It is recommended to install the D compiler by downloading it from the official distribution page.
```sh
# link https://dlang.org/download.html
curl -fsS https://dlang.org/install.sh | bash -s dmd
```

For users running Ubuntu one of the dependencies can be installed with apt.
```sh
sudo apt install x
```

Download the D compiler of your choice, extract it and add to your PATH shell
variable.
```sh
# example with an extracted DMD
export PATH=/path/to/dmd/linux/bin64/:$PATH
```

Once the dependencies are installed it is time to download the source code to install signald-client.
```sh
git clone https://github.com/joakim-brannstrom/signald-client.git
cd signald-client
dub build -b release
```

Done! Have fun.
Don't be shy to report any issue that you find.
