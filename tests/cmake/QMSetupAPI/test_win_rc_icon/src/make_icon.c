/* Writes an icon of 16 by 16 pixels in one color, a 32-bit bitmap with an AND mask, as the
 * resource compiler reads an icon.
 *
 *     qmtest_make_icon <out.ico> <color>
 *
 * The color is a number from 0 to 3, so that a test writes the same icon again in another color.
 */
#define _CRT_SECURE_NO_WARNINGS

#include <stdio.h>
#include <stdlib.h>

static void put16(FILE *file, unsigned long value) {
    fputc((int) (value & 0xff), file);
    fputc((int) ((value >> 8) & 0xff), file);
}

static void put32(FILE *file, unsigned long value) {
    put16(file, value & 0xffff);
    put16(file, (value >> 16) & 0xffff);
}

int main(int argc, char **argv) {
    /* Opaque black, red, blue and green, as 0xAARRGGBB, which a little-endian BGRA pixel holds */
    static const unsigned long colors[] = {0xff000000ul, 0xffff0000ul, 0xff0000fful, 0xff00ff00ul};
    const int size = 16;
    const unsigned long pixels = (unsigned long) (size * size * 4);
    /* One row of the mask is 4 bytes, the 16 bits of a row padded to 32 */
    const unsigned long mask = (unsigned long) (size * 4);
    unsigned long color;
    FILE *file;
    int i;

    if (argc != 3) {
        fprintf(stderr, "usage: qmtest_make_icon <out.ico> <color>\n");
        return 1;
    }
    color = colors[atoi(argv[2]) & 3];
    file = fopen(argv[1], "wb");
    if (!file) {
        return 1;
    }

    /* The directory: one image of 16 by 16 pixels at 32 bits, which starts at byte 22 */
    put16(file, 0);
    put16(file, 1);
    put16(file, 1);
    fputc(size, file);
    fputc(size, file);
    fputc(0, file);
    fputc(0, file);
    put16(file, 1);
    put16(file, 32);
    put32(file, 40 + pixels + mask);
    put32(file, 22);

    /* The bitmap header, whose height counts the pixels and the mask */
    put32(file, 40);
    put32(file, (unsigned long) size);
    put32(file, (unsigned long) (size * 2));
    put16(file, 1);
    put16(file, 32);
    put32(file, 0);
    put32(file, pixels + mask);
    put32(file, 0);
    put32(file, 0);
    put32(file, 0);
    put32(file, 0);

    for (i = 0; i < size * size; ++i) {
        put32(file, color);
    }
    for (i = 0; i < (int) mask; ++i) {
        fputc(0, file);
    }
    return fclose(file) == 0 ? 0 : 1;
}
