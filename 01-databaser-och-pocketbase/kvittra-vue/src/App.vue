<script setup>
import { ref, onMounted } from 'vue'
import PocketBase from 'pocketbase'

// Adressen till din PocketBase. Den måste vara igång (.\pocketbase serve).
const pb = new PocketBase('http://127.0.0.1:8090')

const users = ref([])

async function loadUsers() {
  users.value = await pb.collection('users').getFullList({ sort: 'username' })
}

// Körs en gång när sidan har visats.
onMounted(() => {
  loadUsers()
})
</script>

<template>
  <main>
    <h1>Kvittra</h1>

    <h2>Användare</h2>
    <ul>
      <li v-for="user in users" :key="user.id">
        {{ user.username }} – {{ user.name }}
      </li>
    </ul>

    <!-- Lägg till dina egna listor och formulär här under -->
  </main>
</template>

<style>
body {
  font-family: system-ui, sans-serif;
  max-width: 700px;
  margin: 2rem auto;
  padding: 0 1rem;
}

.error {
  color: white;
  background: #c0392b;
  padding: 0.5rem 1rem;
  border-radius: 4px;
}

form {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  max-width: 400px;
}

pre {
  background: #f4f4f4;
  padding: 1rem;
  overflow-x: auto;
}
</style>
