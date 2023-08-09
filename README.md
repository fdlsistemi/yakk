![image](https://github.com/fdlsistemi/yakk/assets/5124379/deecca3a-1164-41d4-b719-b9faad999cd0)
<br />Photo by <a href="https://unsplash.com/@paoloficasso?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Paolo Feser</a> on <a href="https://unsplash.com/photos/sI2pmha9vRI?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Unsplash</a>

<h1>YAK<sup>2</sup> (Yet Another K8S Kickstart)</h1>

Did we really need <b>Yet Another Kubernetes Kickstart (YAKK –> YAK2)</b> script to nearly automatically deploy a K8S cluster? Didn’t we already have enough alternatives (you can search on Google to find tons of examples) to setup a demo/lab/test/POC environment? Probably yes, nevertheless…

I created mine. It all started as self-practice to learn how to setup Kubernetes using <code>kubeadm</code>, then it evolved into something more structured and – in the end – I eventually decided to share it with anyone who may benefit from it.

The starting point was using a given Linux distro we – when we deal with VMware products – know very well: Photon OS, “a Linux based, open source, security-hardened, enterprise grade appliance operating system that is purpose built for Cloud and Edge applications” (the description was promising).

For the script full description and usage instructions, check <a href="https://www.fdlsistemi.com/yak2/" target="_blank" rel="noopener noreferrer">https://www.fdlsistemi.com/yak2/</a>.

Script - with the following components releases - has been tested last on: August 9th 2023.
<table>
  <tr><th>Component</th><th>Version</th></tr>
  <tr><td>PhotonOS 5.0 kernel</td><td>6.1.41-1.ph5-esx</td></tr>
  <tr><td>containerd</td><td>1.7.3</td></tr>
  <tr><td>runc</td><td>1.1.8</td></tr>
  <tr><td>CNI plugins</td><td>1.3.0</td></tr>
  <tr><td>Kubernetes</td><td>1.27.4</td></tr>
  <tr><td>Antrea</td><td>1.13.0</td></tr>
  <tr><td>NFS subdir</td><td>4.0.18</td></tr>
  <tr><td>MetalLB</td><td>0.13.10</td></tr>
  <tr><td>Kubeapps</td><td>2.8.0</td></tr>
</table>
