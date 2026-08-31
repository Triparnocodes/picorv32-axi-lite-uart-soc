import subprocess
import os
import shutil

def run_commands(input_file):
    current_dir = os.path.basename(os.getcwd())

    # If already inside 'fw', use current dir
    if current_dir == "fw":
        fw_dir = "."
        parent_dir = os.path.abspath("..")
    else:
        fw_dir = "fw"
        os.makedirs(fw_dir, exist_ok=True)
        parent_dir = os.getcwd()

    base_name = os.path.splitext(input_file)[0]

    # Output paths
    o_file = f"{fw_dir}/{base_name}.o"
    elf_file = f"{fw_dir}/{base_name}.elf"
    dump_file = f"{fw_dir}/{base_name}.dump"
    bin_file = f"{fw_dir}/{base_name}.bin"
    raw_hex_file = f"{fw_dir}/{base_name}_raw.hex"
    hex_file = f"{fw_dir}/{base_name}.hex"

    # 1. Assemble
    subprocess.run(
        f"riscv64-unknown-elf-as -o {o_file} {input_file}",
        shell=True, check=True
    )

    # 2. Link
    subprocess.run(
        f"riscv64-unknown-elf-ld -e _start -o {elf_file} {o_file}",
        shell=True, check=True
    )

    # 3. Disassemble
    subprocess.run(
        f"riscv64-unknown-elf-objdump -d {elf_file} > {dump_file}",
        shell=True, check=True
    )

    # 4. ELF → binary
    subprocess.run(
        f"riscv64-unknown-elf-objcopy -O binary {elf_file} {bin_file}",
        shell=True, check=True
    )

    # 5. Binary → raw hex
    subprocess.run(
        f"riscv64-unknown-elf-objcopy -I binary -O verilog {bin_file} {raw_hex_file}",
        shell=True, check=True
    )

    # 6. Fix endianness
    with open(raw_hex_file, "r") as infile, open(hex_file, "w") as outfile:
        bytes_list = []

        for line in infile:
            line = line.strip()
            if not line or line.startswith('@'):
                continue
            bytes_list.extend(line.split())

        for i in range(0, len(bytes_list), 4):
            if i + 3 < len(bytes_list):
                b0, b1, b2, b3 = bytes_list[i:i+4]
                word = (b3 + b2 + b1 + b0).upper()
                outfile.write(word + "\n")

    # 🔥 Copy to parent directory
    dest_hex = os.path.join(parent_dir, f"{base_name}.hex")
    shutil.copy(hex_file, dest_hex)

    print(f"\n✔ Output saved to {hex_file}")
    print(f"✔ Copied to parent directory: {dest_hex}")


if __name__ == "__main__":
    default_file = "code.S"

    if os.path.isfile(default_file):
        print("✔ Found code.S, running automatically...")
        run_commands(default_file)
    else:
        input_file = input("Enter assembly file: ")
        if os.path.isfile(input_file):
            run_commands(input_file)
        else:
            print(f"File '{input_file}' not found.")