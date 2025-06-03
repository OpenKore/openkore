package npcName;

use strict;
use Plugins;
use Settings;
use Globals;
use Log qw(message warning error debug);
use Utils qw(existsInList);

Plugins::register('npcName', 'Tradução de NPCs', \&onUnload);
my $hooks = Plugins::addHooks(
    ['packet_pre/npc_talk', \&translate_npc_pre, undef],
    ['packet/npc_talk', \&translate_npc, undef],
    ['packet/npc_talk_number', \&translate_npc, undef],
    ['packet/npc_talk_text', \&translate_npc, undef],
    ['packet/npc_store_begin', \&translate_npc, undef],
    ['packet/npc_store_info', \&translate_npc, undef],
    ['packet/npc_sell_list', \&translate_npc, undef],
    ['packet/actor_display', \&translate_npc_spawn, undef],
    ['packet/actor_exists', \&translate_npc_spawn, undef],
    ['packet/actor_connected', \&translate_npc_spawn, undef],
    ['npc_talk', \&translate_npc_talk, undef],
    ['npc_talk_responses', \&translate_npc_talk, undef],
    ['packet/actor_name_response', \&translate_npc_name, undef]
);

sub onUnload {
    Plugins::delHooks($hooks);
}

my %npc_names = (
    # NPCs básicos
    'mb/1CQ' => 'Vendedor de Equipamentos',
    'mL/1CQ' => 'Vendedor de Itens',
    'mr/1CQ' => 'Vendedor de Poções',
    'zb/1CQ' => 'Kafra',
    'xf/1CQ' => 'Funcionário da Guilda',
    'en/1CQ' => 'Guia',
    'es/1CQ' => 'Vendedor de Habilidades',
    'wz/1CQ' => 'Assistente',
    'ms/1CQ' => 'Mercador',
    'ka/1CQ' => 'Kafra',
    'kf/1CQ' => 'Kafra',
    
    # Padrões comuns
    'Merchant' => 'Mercador',
    'Guide' => 'Guia',
    'Kafra Employee' => 'Funcionária Kafra',
    'Weapon Dealer' => 'Vendedor de Armas',
    'Tool Dealer' => 'Vendedor de Itens',
    'Armor Dealer' => 'Vendedor de Armaduras',
    'Healing Merchant' => 'Vendedor de Poções',
    'Guild Staff' => 'Funcionário da Guilda',
    
    # Outros padrões
    '/1CQ' => '',  # Remove o sufixo /1CQ
    '/CQ' => '',   # Remove o sufixo /CQ
);

# Detecta NPCs desconhecidos e registra para futura tradução
my %unknown_npcs;

# Traduz antes do pacote ser processado
sub translate_npc_pre {
    my (undef, $args) = @_;
    my $name = $args->{name};
    
    if ($name) {
        # Remove sufixos comuns
        $name =~ s/\/1CQ$//;
        $name =~ s/\/CQ$//;
        
        # Tenta traduzir
        if (exists $npc_names{$name}) {
            $args->{name} = $npc_names{$name};
        }
    }
}

sub translate_npc {
    my ($hook, $args) = @_;
    
    if ($args->{ID} && $npcsList->getByID($args->{ID})) {
        my $npc = $npcsList->getByID($args->{ID});
        my $name = $npc->name;
        
        # Remove sufixos comuns
        $name =~ s/\/1CQ$//;
        $name =~ s/\/CQ$//;
        
        if (exists $npc_names{$name}) {
            $npc->{name} = $npc_names{$name};
            debug "[npcName] NPC traduzido: $name -> $npc_names{$name}\n", "npcName";
        } else {
            # Registra NPCs desconhecidos
            unless (exists $unknown_npcs{$name}) {
                $unknown_npcs{$name} = 1;
                debug "[npcName] NPC desconhecido detectado: $name\n", "npcName";
                message "[npcName] Novo NPC encontrado: $name\n", "npcName";
            }
        }
    }
}

sub translate_npc_spawn {
    my ($hook, $args) = @_;
    
    if ($args->{type} == 45) { # 45 é o tipo de ator para NPCs
        translate_npc($hook, $args);
    }
}

sub translate_npc_talk {
    my ($hook, $args) = @_;
    
    if ($args->{ID} && $args->{msg}) {
        my $npc = $npcsList->getByID($args->{ID});
        if ($npc) {
            translate_npc($hook, {ID => $args->{ID}});
        }
    }
}

sub translate_npc_name {
    my ($hook, $args) = @_;
    
    if ($args->{ID} && $args->{name}) {
        my $name = $args->{name};
        
        # Remove sufixos comuns
        $name =~ s/\/1CQ$//;
        $name =~ s/\/CQ$//;
        
        if (exists $npc_names{$name}) {
            $args->{name} = $npc_names{$name};
            debug "[npcName] Nome de NPC traduzido: $name -> $npc_names{$name}\n", "npcName";
        }
    }
}

# Comando para listar NPCs desconhecidos
Commands::register(["npcs", "Lista NPCs desconhecidos", \&cmd_list_unknown_npcs]);

sub cmd_list_unknown_npcs {
    message "=== NPCs Desconhecidos ===\n", "list";
    foreach my $name (sort keys %unknown_npcs) {
        message "$name\n", "list";
    }
    message "========================\n", "list";
    message "Total de NPCs não traduzidos: " . scalar(keys %unknown_npcs) . "\n", "list";
} 