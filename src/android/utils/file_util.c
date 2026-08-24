#include <dirent.h>
#include <sys/types.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

void read_file_list(const char* dir_path)
{
    DIR* dir = opendir(dir_path);
    if (dir == NULL) {
        printf("failed to open dir: %s, err: %s\n", dir_path, strerror(errno));
        return;
    }

    struct dirent* dptr = NULL;
    while ((dptr = readdir(dir)) != NULL) {
        /*
         * only Btrfs, ext2, ext3, ext4 have full support for
         * returning the file type in d_type
         */
#define print_d_info(x) \
    case (x): \
        printf("read file type: "#x", name: %s\n", dptr->d_name); \
        break

        switch (dptr->d_type) {
        print_d_info(DT_BLK);
        print_d_info(DT_CHR);
        print_d_info(DT_DIR);
        print_d_info(DT_FIFO);
        print_d_info(DT_LNK);
        print_d_info(DT_REG);
        print_d_info(DT_SOCK);
        print_d_info(DT_UNKNOWN);
#undef print_d_info
        }
    }
    closedir(dir);
}

void main(void)
{
    read_file_list(".");
}
