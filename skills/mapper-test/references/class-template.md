# 類別結構範本

```java
package <same.package.as.mapper>;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.instancio.Instancio;
import org.instancio.junit.InstancioExtension;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

// ... 其他 import

@ExtendWith({SpringExtension.class, InstancioExtension.class})
@Import(<MapperName>Impl.class)
class <MapperName>Test {

    @Autowired
    private <MapperName> mapper;

    // 若方法有 enum 參數（例如 CategoryType）：
    private static final CategoryType CATEGORY_TYPE = CategoryType.values()[0];

    // ── <methodName> ──────────────────────────────────────────────

    @Test
    void <methodName>_allFields_mappedCorrectly() {
        <SourceType> source = Instancio.create(<SourceType>.class);

        <ReturnType> result = mapper.<methodName>(source);

        MapperTestUtils.assertAllFieldsMapped(source, result);
    }

    // ... 其餘方法
}
```
