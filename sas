from google.cloud import compute_v1
import time

# Configurações iniciais
PROJECT_ID = 'seu-projeto-gcp'
ZONE = 'us-central1-a'
INSTANCE_NAME = 'web-server'
MACHINE_TYPE = 'n1-standard-1'
IMAGE_FAMILY = 'debian-11'
IMAGE_PROJECT = 'debian-cloud'
FIREWALL_NAME = 'allow-http'

# Criação da VM
def create_instance():
    instance_client = compute_v1.InstancesClient()

    # Configuração da VM
    config = compute_v1.Instance()
    config.name = INSTANCE_NAME
    config.machine_type = f"zones/{ZONE}/machineTypes/{MACHINE_TYPE}"

    # Disco de boot
    disk = compute_v1.AttachedDisk()
    disk.auto_delete = True
    disk.boot = True
    disk.initialize_params.source_image = f"projects/{IMAGE_PROJECT}/global/images/family/{IMAGE_FAMILY}"
    config.disks = [disk]

    # Interface de rede
    network_interface = compute_v1.NetworkInterface()
    network_interface.network = 'global/networks/default'
    config.network_interfaces = [network_interface]

    # Cria a instância
    operation = instance_client.insert(project=PROJECT_ID, zone=ZONE, instance_resource=config)
    print('Criando VM...')
    wait_for_operation(operation.name)

    print(f'Instância {INSTANCE_NAME} criada com sucesso.')

# Aguarda até a operação terminar
def wait_for_operation(operation_name):
    operation_client = compute_v1.ZoneOperationsClient()
    while True:
        result = operation_client.get(project=PROJECT_ID, zone=ZONE, operation=operation_name)
        if result.status == 'DONE':
            print('Operação concluída.')
            break
        time.sleep(5)

# Configuração do firewall
def create_firewall_rule():
    firewall_client = compute_v1.FirewallsClient()

    firewall_rule = compute_v1.Firewall()
    firewall_rule.name = FIREWALL_NAME
    firewall_rule.allowed = [compute_v1.Allowed(protocol='tcp', ports=['80', '443'])]
    firewall_rule.direction = compute_v1.Firewall.Direction.INGRESS
    firewall_rule.source_ranges = ['0.0.0.0/0']
    firewall_rule.network = 'global/networks/default'

    firewall_client.insert(project=PROJECT_ID, firewall_resource=firewall_rule)
    print(f'Firewall {FIREWALL_NAME} configurado para liberar HTTP e HTTPS.')

# Instalação do Apache
INSTALL_SCRIPT = """
#! /bin/bash
sudo apt update
sudo apt install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
"""

def add_startup_script():
    instance_client = compute_v1.InstancesClient()
    metadata = compute_v1.Metadata()
    metadata.items = [
        compute_v1.Items(key='startup-script', value=INSTALL_SCRIPT)
    ]
    instance_client.set_metadata(project=PROJECT_ID, zone=ZONE, instance=INSTANCE_NAME, metadata_resource=metadata)
    print('Script de inicialização adicionado.')

if __name__ == '__main__':
    create_instance()
    create_firewall_rule()
    add_startup_script()
    print('Servidor web provisionado com sucesso!')
