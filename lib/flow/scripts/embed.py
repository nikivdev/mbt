from pathlib import Path
from dataclasses import dataclass
import subprocess


@dataclass
class Manifest:
    source: Path
    destination: Path
    name: str
    is_pub: bool
    is_const: bool

    def embed(self) -> None:
        text = self.source.read_text()
        lines = ["///|"]
        if self.is_pub:
            if self.is_const:
                lines.append(f"pub const {self.name} : String =")
            else:
                lines.append(f"pub let {self.name} : String =")
        else:
            if self.is_const:
                lines.append(f"const {self.name} : String =")
            else:
                lines.append(f"let {self.name} : String =")
        for line in text.splitlines():
            lines.append(f"  #|{line}")
        lines.append("")
        self.destination.write_text("\n".join(lines))
        print(f"EMBED {self.source} -> {self.destination}")


manifests = [
    Manifest(
        source=Path("prompt/system-prompt/Agents.mbt.md"),
        destination=Path("prompt/moonbit.mbt"),
        name="moonbit",
        is_pub=True,
        is_const=False,
    )
]


def main():
    subprocess.run(["git", "submodule", "update", "--init", "--recursive"], check=True)
    for manifest in manifests:
        manifest.embed()


if __name__ == "__main__":
    main()
