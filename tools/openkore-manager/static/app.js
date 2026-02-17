const instancesEl = document.getElementById('instances');
const template = document.getElementById('instance-template');

async function api(path, options = {}) {
  const res = await fetch(path, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Erro na API');
  return data;
}

function actionPath(instanceId, target, action) {
  return `/api/instances/${instanceId}/actions/${target}/${action}`;
}

async function runAction(instanceId, action) {
  if (action === 'logs') return loadLogs(instanceId, 'bot');
  if (action === 'clone') {
    const name = window.prompt('Nome da cópia:');
    if (!name) return;
    await api(`/api/instances/${instanceId}/clone`, {
      method: 'POST',
      body: JSON.stringify({ name }),
    });
    return loadInstances();
  }

  const [verb, target] = action.split('-');
  await api(actionPath(instanceId, target, verb), { method: 'POST', body: '{}' });
  await loadInstances();
}

async function loadLogs(instanceId, target) {
  const data = await api(`/api/instances/${instanceId}/logs?target=${target}&tail=300`);
  const pre = document.querySelector(`pre[data-id="${instanceId}"]`);
  if (!pre) return;
  pre.textContent = data.logs.join('\n') || '[sem logs em memória]';
  pre.classList.remove('hidden');
}

async function loadInstances() {
  const data = await api('/api/instances');
  instancesEl.innerHTML = '';

  data.forEach((item) => {
    const node = template.content.cloneNode(true);
    node.querySelector('.name').textContent = item.name;
    node.querySelector('.meta').textContent = `ID: ${item.id} | XKore ${item.xkore_mode} | ${item.working_dir}`;
    node.querySelector('.pill').textContent = `Bot: ${item.bot_running ? 'ON' : 'OFF'} | Poseidon: ${item.poseidon_running ? 'ON' : 'OFF'}`;

    const pre = node.querySelector('pre');
    pre.dataset.id = item.id;

    node.querySelectorAll('button[data-action]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        try {
          await runAction(item.id, btn.dataset.action);
        } catch (error) {
          window.alert(error.message);
        }
      });
    });

    instancesEl.appendChild(node);
  });
}

const createForm = document.getElementById('create-form');
createForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = new FormData(createForm);
  const payload = Object.fromEntries(form.entries());
  try {
    await api('/api/instances', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    createForm.reset();
    await loadInstances();
  } catch (error) {
    window.alert(error.message);
  }
});

document.getElementById('refresh').addEventListener('click', loadInstances);
loadInstances();
