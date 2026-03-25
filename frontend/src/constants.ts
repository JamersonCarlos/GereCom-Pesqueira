import { User, Planning, Service } from './types';

export const COLORS = {
  primary: '#2E51A4',
  secondary: '#F1C62F',
  white: '#ffffff',
};

export const MOCK_USERS: User[] = [
  { 
    id: 'u1', 
    username: 'admin', 
    password: '123', 
    name: 'Gerente Demo', 
    role: 'MANAGER', 
    status: 'ACTIVE', 
    function: 'Gerente Geral',
    createdAt: new Date().toISOString()
  },
];

export const SERVICE_TYPES = [
  'Cobertura Fotográfica',
  'Produção Audiovisual',
  'Design Gráfico',
  'Publicação em Redes Sociais',
  'Assessoria de Imprensa',
  'Evento Institucional',
];

export const DEPARTMENTS = [
  'Saúde',
  'Educação',
  'Obras',
  'Cultura',
  'Esporte',
  'Gabinete',
  'SEASIC Mulher',
  'SEASIC',
  'SICTEC',
];
