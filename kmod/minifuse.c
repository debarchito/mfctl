// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (c) 2026 Pavel Olizko <contact@nolight.dev>
 * Copyright (c) 2026 sleebu <contact@sleebu.dev>
 */
#include <linux/fs.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/usb.h>

#define MINIFUSE_VID 0x1c75

static struct usb_device *minifuse_udev = NULL;

static int match_minifuse(struct usb_device *udev, void *data) {
  if (le16_to_cpu(udev->descriptor.idVendor) == MINIFUSE_VID) {
    minifuse_udev = usb_get_dev(udev);
    return 1;
  }
  return 0;
}

static ssize_t mftoggle_write(struct file *file, const char __user *user_buf,
                              size_t count, loff_t *ppos) {
  char buf[32];
  size_t len = min(count, sizeof(buf) - 1);
  unsigned short selector = 0;
  int enable = 0;
  u8 *data;
  int ret;

  // Safely copy the string from userspace to kernel space
  if (copy_from_user(buf, user_buf, len))
    return -EFAULT;
  buf[len] = '\0';

  minifuse_udev = NULL;
  usb_for_each_dev(NULL, match_minifuse);

  if (!minifuse_udev) {
    printk(KERN_ERR "MiniFuse: Device not found\n");
    return -ENODEV;
  }

  if (sscanf(buf, "%hx %d", &selector, &enable) != 2) {
    usb_put_dev(minifuse_udev);
    return -EINVAL;
  }

  data = kmalloc(2, GFP_KERNEL);
  if (!data) {
    usb_put_dev(minifuse_udev);
    return -ENOMEM;
  }

  data[0] = enable ? 1 : 0;
  data[1] = 0;

  ret = usb_control_msg(minifuse_udev, usb_sndctrlpipe(minifuse_udev, 0), 34,
                        0x21, selector, 0, data, 2, 200);

  kfree(data);
  usb_put_dev(minifuse_udev);

  if (ret < 0) {
    printk(KERN_ERR "MiniFuse: usb_control_msg failed (%d)\n", ret);
    return ret;
  }

  return count;
}

static const struct file_operations mf_fops = {
    .owner = THIS_MODULE,
    .write = mftoggle_write,
};

static struct miscdevice mf_misc = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = "minifuse_cmd",
    .fops = &mf_fops,
    .mode = 0222, // World-writable is fully allowed for character devices!
};

static int __init mf_init(void) { return misc_register(&mf_misc); }

static void __exit mf_exit(void) { misc_deregister(&mf_misc); }

module_init(mf_init);
module_exit(mf_exit);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Pavel Olizko <contact@nolight.dev>");
MODULE_AUTHOR("sleebu <contact@sleebu.dev>");
MODULE_DESCRIPTION("Bypass usbfs to send control commands to Arturia MiniFuse");
