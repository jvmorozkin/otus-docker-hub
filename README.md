# otus-docker-hub
This is training repo for course. Second homework.

Here is minimal-health-service on Spring Boot with gradle

Mermaid diagramm:

```mermaid
graph TD
    Client((Клиент Браузер / Мобильное приложение)) --> |HTTP| API_Gateway[API Gateway - Spring Cloud Gateway]

    API_Gateway --> |HTTP| Auth_Service
    API_Gateway --> |HTTP| ProductCatalogService
    API_Gateway --> |HTTP| ShoppingCartService
    API_Gateway --> |HTTP| OrderService

    subgraph "Микросервисы (Spring Boot)"
        Auth_Service[Сервис аутентификации - Auth Service]
        ProductCatalogService[Каталог товаров - Product Catalog Service]
        ShoppingCartService[Сервис корзины - Shopping Cart Service]
        OrderService[Сервис заказов - Order Service]
        InventoryService[Сервис инвентаря - Inventory Service]
        PaymentService[Сервис оплаты - Payment Service]
        NotificationService[Сервис уведомлений - Notification Service]
        Kafka[(Apache Kafka - Шина событий)]
    end

    %% Связь: Корзина → Каталог (валидация при добавлении)
    ShoppingCartService --> |GET products by id| ProductCatalogService
    %% Или альтернативно (через события):
    ProductCatalogService --> |Событие: ProductUpdated| Kafka
    Kafka --> |ProductUpdated| ShoppingCartService

    %% Основной поток заказа
    ShoppingCartService --> |Создать заказ| OrderService

    OrderService --> |Событие: OrderCreated| Kafka
    Kafka --> |OrderCreated| InventoryService
    Kafka --> |OrderCreated| NotificationService

    InventoryService --> |Событие: InventoryReserved| Kafka
    Kafka --> |InventoryReserved| OrderService

    OrderService --> |Событие: PaymentRequired| Kafka
    Kafka --> |PaymentRequired| PaymentService

    PaymentService --> |Событие: PaymentSuccessful| Kafka
    Kafka --> |PaymentSuccessful| OrderService
    Kafka --> |PaymentSuccessful| NotificationService

    InventoryService --> |Событие: OutOfStock| Kafka
    Kafka --> |OutOfStock| OrderService
    Kafka --> |OutOfStock| NotificationService

    style Auth_Service fill:#4A90E2,stroke:#333,color:white
    style ProductCatalogService fill:#9FCAE6,stroke:#333,color:black
    style ShoppingCartService fill:#9FCAE6,stroke:#333,color:black
    style OrderService fill:#9FCAE6,stroke:#333,color:black
    style InventoryService fill:#9FCAE6,stroke:#333,color:black
    style PaymentService fill:#9FCAE6,stroke:#333,color:black
    style NotificationService fill:#9FCAE6,stroke:#333,color:black
    style API_Gateway fill:#FFD700,stroke:#333,color:black
    style Kafka fill:#E57373,stroke:#333,color:white

    classDef service fill:#9FCAE6,stroke:#2171B5,stroke-width:2px,color:black;
    classDef gateway fill:#FFD700,stroke:#333,stroke-width:2px,color:black;
    classDef message fill:#E57373,stroke:#333,stroke-width:2px,color:white;
```
    class ProductCatalogService,ShoppingCartService,OrderService,InventoryService,PaymentService,NotificationService service
    class API_Gateway gateway
    class Auth_Service auth
    class Kafka message
