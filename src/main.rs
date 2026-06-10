use rusb::{DeviceHandle, GlobalContext};
use std::{env, fs, path::Path, thread::sleep, time::Duration};

const VID: u16 = 0x1c75;
const PID_MF1: u16 = 0xaf80;
const PID_MF2: u16 = 0xaf90;
const SYSFS_PATH: &str = "/dev/minifuse_cmd";

fn parse_selector(target: &str) -> Option<u16> {
    match target {
        "inst" => Some(0x0000),
        "48v" => Some(0x0400),
        "direct-monitor" => Some(0x0500),
        _ => None,
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let pairs_args = &args[1..];

    if pairs_args.is_empty() || pairs_args.len() % 2 != 0 {
        eprintln!("Usage: mfctl <inst|48v|direct-monitor> <on|off> [...]");
        std::process::exit(1);
    }

    let mut commands: Vec<(u16, bool, &str)> = Vec::new();
    for chunk in pairs_args.chunks(2) {
        let target = chunk[0].as_str();
        let state = chunk[1].as_str();

        let selector = match parse_selector(target) {
            Some(s) => s,
            None => {
                eprintln!("Error: Unknown option '{}'. Use 'inst', '48v' or 'direct-monitor'.", target);
                std::process::exit(1);
            }
        };

        if state != "on" && state != "off" {
            eprintln!("Error: Unknown state '{}' for option '{}'.", state, target);
            std::process::exit(1);
        }

        commands.push((selector, state == "on", target));
    }

    if !Path::new(SYSFS_PATH).exists() {
        eprintln!("Error: Kernel module not found at {}", SYSFS_PATH);
        std::process::exit(1);
    }

    for (selector, enable, target) in &commands {
        let cmd = format!("{:04x} {}", selector, if *enable { 1 } else { 0 });
        if let Err(e) = fs::write(SYSFS_PATH, &cmd) {
            eprintln!("Failed to write command for {}: {}", target, e);
        }
        sleep(Duration::from_millis(50));
    }
}
