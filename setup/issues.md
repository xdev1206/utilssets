# ModuleNotFoundError: No module named ‘_tkinter’

Because you installed a new python version that newer than the one in your system or repository, or you installed it to a location different than usr/lib/python3.x (in my case, usr/local/lib/python3.9.4), installing the package python3-tk will not help you directly.

To solve this problem, firstly you need to search for the right python3-tk.*deb file. For my case, I use python3.9.4, so the newest file I can find is python3-tk_3.9.2-1_amd64.deb

As long as it matches the second minor version number, it will work just fine.

Then, after you downloaded that deb file, extract it with any Archive Manager. Continue to extract the data.tar.xz inside.

Then, navigate to data /usr/lib/python3.9/lib-dynload/, you will see there is a pre-built shared lib file `_tkinter.cpython-39-x86_64-linux-gnu.so`.

Finally, all you have to do is to copy that file to the correct folder of your python installation. In my case, it is `/usr/local/lib/python3.9/lib-dynload/`.
