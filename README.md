# aria2-initrd

A minimal initrd implementation using `aria2` for downloading files during the early boot process. This project is designed for environments where fetching large files (e.g., container images or boot configurations) from remote sources is essential.

## Features

- **Containerized Build Process:** Uses a Docker container to ensure a consistent and reproducible build environment.
- **Efficient File Downloads:** Utilizes [aria2](https://github.com/aria2/aria2), a lightweight and high-performance download utility supporting HTTP(S), FTP, and BitTorrent protocols.
- **Lightweight Design:** Aimed at minimal environments, keeping the initrd as small as possible.
- **Highly Configurable:** Supports passing custom download URLs and options through kernel parameters.
- **Parallelism:** Leverages aria2's ability to perform concurrent downloads for faster bootstrapping.

## Use Cases

- **HPC Cluster Bootstrapping:** Fetching configuration files or images for stateless node setups.
- **Diskless Systems:** Loading operating system components or tools directly into memory.
- **Custom Deployment Workflows:** Downloading initialization resources for custom boot environments.



# Testing

1. Use [QEMU](https://www.qemu.org/) or another virtualization platform to test the generated initrd:
   ```bash
   qemu-system-x86_64 -kernel /path/to/vmlinuz -initrd output/initrd.img -append "url=http://example.com/resource"
   ```

2. Monitor the output logs to confirm the download process.


## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgments

- Inspired by the flexibility and power of `aria2`.
- Designed with HPC cluster bootstrapping and custom deployments in mind.
