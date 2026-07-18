#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void skip_comments(FILE *fp) {
    int c;
    while ((c = fgetc(fp)) == '#') {
        while (fgetc(fp) != '\n');
    }
    ungetc(c, fp);
}

int main(int argc, char **argv) {
    if (argc != 3) {
        printf("Usage: %s input.ppm output.mem\n", argv[0]);
        return 1;
    }

    FILE *in = fopen(argv[1], "rb");
    if (!in) {
        perror("Could not open input file");
        return 1;
    }

    FILE *out = fopen(argv[2], "w");
    if (!out) {
        perror("Could not open output file");
        fclose(in);
        return 1;
    }

    char magic[3];
    fscanf(in, "%2s", magic);

    if (strcmp(magic, "P6") != 0) {
        printf("Only binary PPM (P6) files are supported\n");
        return 1;
    }

    int width, height, maxval;

    skip_comments(in);
    fscanf(in, "%d", &width);

    skip_comments(in);
    fscanf(in, "%d", &height);

    skip_comments(in);
    fscanf(in, "%d", &maxval);

    // Consume whitespace after maxval
    fgetc(in);

    if (maxval != 255) {
        printf("Only 8-bit PPM files supported (maxval=255)\n");
        return 1;
    }

    printf("Image: %dx%d\n", width, height);

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {

            uint8_t r = fgetc(in);
            uint8_t g = fgetc(in);
            uint8_t b = fgetc(in);

            uint32_t pixel =
                ((uint32_t)r << 24) |
                ((uint32_t)g << 16) |
                ((uint32_t)b << 8);

            fprintf(out, "%08X\n", pixel);
        }
    }

    fclose(in);
    fclose(out);

    printf("Generated %s\n", argv[2]);

    return 0;
}